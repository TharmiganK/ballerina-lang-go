// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

// Client-side response data binding. Mirrors jBallerina's processResponse /
// performDataBinding chain: the target type decides whether the caller gets the raw
// http:Response, a status-code error, or a value deserialised from the response body
// according to the Content-Type header.

package native

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/url"
	"regexp"
	"strconv"
	"strings"

	"ballerina/runtime/extern"
	"ballerina/semtypes"
	"ballerina/values"
)

// Content-Type classifiers, copied verbatim from jBallerina's AbstractPayloadBuilder so
// the builder chosen for a given media type is identical.
var (
	jsonContentType        = regexp.MustCompile(`^(application|text)/(.*[.+-]|)json$`)
	xmlContentType         = regexp.MustCompile(`^(application|text)/(.*[.+-]|)xml$`)
	textContentType        = regexp.MustCompile(`^(text)/(.*[.+-]|)plain$`)
	octetStreamContentType = regexp.MustCompile(`^(application)/(.*[.+-]|)octet-stream$`)
	urlEncodedContentType  = regexp.MustCompile(`^(application)/(.*[.+-]|)x-www-form-urlencoded$`)
)

// argAt returns the argument at index i, or nil when the caller supplied fewer arguments,
// so that a mismatch between a remote method's declared parameters and the index its handler
// reads is reported by bindResponse instead of panicking on the slice access.
func argAt(args []values.BalValue, i int) values.BalValue {
	if i >= len(args) {
		return nil
	}
	return args[i]
}

// bindResponse turns a received response into the value the call site asked for.
// A target type that admits an http:Response yields the response untouched; otherwise a
// 4xx/5xx status becomes an error carrying the status detail, and any other status is
// deserialised into the target type.
func bindResponse(ctx *extern.Context, types *httpTypes, resp *values.Object, targetArg values.BalValue) values.BalValue {
	td, ok := targetArg.(*values.TypeDesc)
	if !ok {
		// Every remote method that binds declares `TargetType targetType = <>`, so desugar
		// always supplies the typedesc. Returning the response here instead would hand back
		// a value outside the declared return type.
		return payloadBindingError("the targetType argument is missing", nil)
	}
	tc := ctx.TypeCtx()
	target := td.Type
	if admitsResponse(tc, target) {
		return resp
	}
	statusCode := responseStatusCode(resp)
	if statusCode >= 400 && statusCode <= 599 {
		return statusCodeError(ctx, types, resp, statusCode)
	}
	return performDataBinding(ctx, types, resp, target)
}

// admitsResponse reports whether the target type can hold an http:Response. Responses are
// stamped with the top object type, so any object member in the target union counts —
// matching jBallerina's hasHttpResponseType, which is true for an OBJECT tag anywhere in
// the union.
func admitsResponse(tc semtypes.Context, target semtypes.SemType) bool {
	return !semtypes.IsEmpty(tc, semtypes.Intersect(target, semtypes.OBJECT))
}

func responseStatusCode(resp *values.Object) int {
	v, _ := resp.Get("statusCode")
	code, _ := v.(int64)
	return int(code)
}

// statusCodeError mirrors jBallerina's createResponseError: the error message is the reason
// phrase and the detail carries the status code, headers, and extracted body. The distinct
// types ClientRequestError and RemoteServerError are not declared in this implementation, so
// the distinction survives only in the error's type name.
func statusCodeError(ctx *extern.Context, types *httpTypes, resp *values.Object, statusCode int) *values.Error {
	body, extractErr := statusErrorPayload(ctx, types, resp)
	if extractErr != nil {
		return values.NewError(semtypes.ERROR, "http:ApplicationResponseError creation failed: "+
			strconv.Itoa(statusCode)+" response payload extraction failed", extractErr,
			"PayloadBindingClientError", nil)
	}
	tc := ctx.TypeCtx()
	detail := newMappingValue()
	detail.Put(tc, "statusCode", int64(statusCode))
	detail.Put(tc, "headers", copyResponseHeaders(tc, resp))
	detail.Put(tc, "body", body)
	typeName := "ClientRequestError"
	if statusCode >= 500 {
		typeName = "RemoteServerError"
	}
	return values.NewError(semtypes.ERROR, reasonPhrase(statusCode), nil, typeName, detail)
}

// statusErrorPayload extracts the error response body the way jBallerina's getPayload does:
// by content type, falling back to text. XML bodies are read as text since the runtime has
// no xml type.
func statusErrorPayload(ctx *extern.Context, types *httpTypes, resp *values.Object) (values.BalValue, *values.Error) {
	body, err := responseBody(resp)
	if err != nil {
		return nil, values.NewErrorWithMessage(err.Error())
	}
	// An absent body carries no payload to extract. Handing it to the builder chosen by the
	// Content-Type would fail — a JSON decoder rejects an empty document — and the resulting
	// extraction error would replace the reason phrase in the error message. A 401 or 404 sent
	// with a JSON content type and no body is common enough that the status must survive.
	if len(body) == 0 {
		return nil, nil
	}
	contentType := baseContentType(resp)
	switch {
	case jsonContentType.MatchString(contentType):
		return decodeJSONBody(ctx, types, body)
	case octetStreamContentType.MatchString(contentType):
		return byteArrayValue(ctx, types, body), nil
	default:
		return string(body), nil
	}
}

// reasonPhrase returns the registered phrase for the status code. The PAL transport reports
// only the status code, so the phrase actually sent on the wire is not available. Codes
// outside the IANA registry — 499, which nginx sends for a client-closed request, among
// others — have no registered phrase, and naming the code keeps the error message from
// coming out empty.
func reasonPhrase(statusCode int) string {
	if phrase := http.StatusText(statusCode); phrase != "" {
		return phrase
	}
	return "status code " + strconv.Itoa(statusCode)
}

func copyResponseHeaders(tc semtypes.Context, resp *values.Object) *values.Map {
	src := responseHeaders(resp)
	out := newMappingValue()
	for _, k := range src.Keys() {
		v, _ := src.Get(k)
		out.Put(tc, k, v)
	}
	return out
}

// performDataBinding picks a builder from the Content-Type header, as jBallerina does, and
// falls back to picking one from the target type when the media type is absent or unknown.
func performDataBinding(ctx *extern.Context, types *httpTypes, resp *values.Object, target semtypes.SemType) values.BalValue {
	// A () target discards the payload. jBallerina routes this through the string builder and
	// hands back the body when it is non-empty; returning () keeps the value within the
	// requested type.
	if semtypes.IsSubtype(ctx.TypeCtx(), target, semtypes.NIL) {
		return nil
	}
	contentType := baseContentType(resp)
	switch {
	case contentType == "":
		return builderFromType(ctx, types, resp, target)
	case xmlContentType.MatchString(contentType):
		return unsupportedXMLTarget(contentType)
	case textContentType.MatchString(contentType):
		return textPayloadBuilder(ctx, types, resp, target, contentType)
	case urlEncodedContentType.MatchString(contentType):
		return formPayloadBuilder(ctx, types, resp, target, contentType)
	case octetStreamContentType.MatchString(contentType):
		return blobPayloadBuilder(ctx, types, resp, target, contentType)
	case jsonContentType.MatchString(contentType):
		return jsonPayloadBuilder(ctx, types, resp, target)
	default:
		return builderFromType(ctx, types, resp, target)
	}
}

// builderFromType infers the builder from the target type alone, used when the response
// carries no usable Content-Type.
func builderFromType(ctx *extern.Context, types *httpTypes, resp *values.Object, target semtypes.SemType) values.BalValue {
	tc := ctx.TypeCtx()
	switch {
	case narrowsTo(tc, target, semtypes.STRING):
		return bindAtTarget(tc, textValue(resp), semtypes.STRING, target)
	case semtypes.IsSubtype(tc, target, semtypes.Union(semtypes.XML, semtypes.NIL)):
		return unsupportedXMLTarget("")
	case narrowsTo(tc, target, types.byteArrTy):
		return bindAtTarget(tc, binaryValue(ctx, types, resp), types.byteArrTy, target)
	default:
		return jsonPayloadBuilder(ctx, types, resp, target)
	}
}

func textPayloadBuilder(ctx *extern.Context, types *httpTypes, resp *values.Object,
	target semtypes.SemType, contentType string) values.BalValue {
	tc := ctx.TypeCtx()
	switch {
	case narrowsTo(tc, target, semtypes.STRING), admits(tc, target, semtypes.STRING):
		return bindAtTarget(tc, textValue(resp), semtypes.STRING, target)
	case narrowsTo(tc, target, types.byteArrTy), admits(tc, target, types.byteArrTy):
		return bindAtTarget(tc, binaryValue(ctx, types, resp), types.byteArrTy, target)
	default:
		return incompatibleTargetError(tc, target, contentType)
	}
}

func formPayloadBuilder(ctx *extern.Context, types *httpTypes, resp *values.Object,
	target semtypes.SemType, contentType string) values.BalValue {
	tc := ctx.TypeCtx()
	switch {
	case narrowsTo(tc, target, types.mapStringTy), admits(tc, target, types.mapStringTy):
		return bindAtTarget(tc, formDataValue(ctx, types, resp), types.mapStringTy, target)
	case narrowsTo(tc, target, semtypes.STRING), admits(tc, target, semtypes.STRING):
		return bindAtTarget(tc, textValue(resp), semtypes.STRING, target)
	default:
		return incompatibleTargetError(tc, target, contentType)
	}
}

func blobPayloadBuilder(ctx *extern.Context, types *httpTypes, resp *values.Object,
	target semtypes.SemType, contentType string) values.BalValue {
	tc := ctx.TypeCtx()
	switch {
	case narrowsTo(tc, target, types.byteArrTy), admits(tc, target, types.byteArrTy):
		return bindAtTarget(tc, binaryValue(ctx, types, resp), types.byteArrTy, target)
	default:
		return incompatibleTargetError(tc, target, contentType)
	}
}

// narrowsTo reports whether target, setting aside a nil member it may have, is a subtype of
// builderTy — the type a payload builder produces. Such a target selects that builder even
// though it may be strictly narrower than what the builder yields: an enum or a singleton
// against `string`, a closed all-string record against `map<string>`, a tuple or a
// fixed-length array against `byte[]`. Ignoring the nil member is what lets the nilable form
// of each of those (`Colour?`, `Form?`) reach the builder; `()` alone does not, and is handled
// before any builder is chosen.
func narrowsTo(tc semtypes.Context, target, builderTy semtypes.SemType) bool {
	bare := semtypes.Diff(target, semtypes.NIL)
	return !semtypes.IsEmpty(tc, bare) && semtypes.IsSubtype(tc, bare, builderTy)
}

// bindAtTarget turns a payload built at the builder's own type — `string`, `map<string>` or
// `byte[]` — into the value the target asks for: an empty body becomes `()` when the target is
// nilable, and a target narrower than builderTy is converted with the routine the json builder
// uses, so a body that does not fit it fails instead of reaching the call site as a value
// outside its declared type. A target that builderTy already fits needs no conversion, which
// keeps the common case free of a clone.
func bindAtTarget(tc semtypes.Context, payload values.BalValue, builderTy, target semtypes.SemType) values.BalValue {
	payload = nilOnEmptyBody(tc, target, payload)
	if payload == nil || admits(tc, target, builderTy) {
		return payload
	}
	if _, failed := payload.(*values.Error); failed {
		return payload
	}
	bound, convErr := values.CloneWithType(tc, payload, target)
	if convErr != nil {
		return payloadBindingError(convErr.Message, convErr)
	}
	return bound
}

// jsonPayloadBuilder parses the body as JSON and converts it to the target type with the
// same conversion the lang.value fromJsonWithType function uses.
//
// jBallerina rejects a target that is neither http:Response nor anydata here. TargetType is
// declared as typedesc<Response|anydata> and a target admitting Response has already been
// returned above, so the remaining target is always a subtype of anydata and the check has
// no counterpart in this implementation.
func jsonPayloadBuilder(ctx *extern.Context, types *httpTypes, resp *values.Object,
	target semtypes.SemType) values.BalValue {
	tc := ctx.TypeCtx()
	body, err := responseBody(resp)
	if err != nil {
		return values.NewErrorWithMessage(err.Error())
	}
	if len(body) == 0 && admits(tc, target, semtypes.NIL) {
		return nil
	}
	payload, jsonErr := decodeJSONBody(ctx, types, body)
	if jsonErr != nil {
		return jsonErr
	}
	bound, convErr := values.CloneWithType(tc, payload, target)
	if convErr != nil {
		return payloadBindingError(convErr.Message, convErr)
	}
	return bound
}

// payloadBindingError builds a binding failure. The message prefix and the error type name
// match jBallerina's PayloadBindingClientError, though the distinct type itself is not declared
// in this implementation.
func payloadBindingError(message string, cause *values.Error) *values.Error {
	return values.NewError(semtypes.ERROR, "Payload binding failed: "+message, cause,
		"PayloadBindingClientError", nil)
}

// unsupportedXMLTarget reports that xml binding is unavailable. The runtime has no xml type,
// so neither an xml target nor an xml response body can be bound.
func unsupportedXMLTarget(contentType string) *values.Error {
	if contentType == "" {
		return payloadBindingError("xml target types are not supported", nil)
	}
	return payloadBindingError("'"+contentType+
		"' responses are not supported because the xml type is not available", nil)
}

func incompatibleTargetError(tc semtypes.Context, target semtypes.SemType, contentType string) *values.Error {
	mimeType := "no"
	if contentType != "" {
		mimeType = "'" + contentType + "'"
	}
	message := "incompatible '" + semtypes.ToString(tc, target) + "' found for " + mimeType + " mime type"
	return values.NewError(semtypes.ERROR, message, nil, "PayloadBindingClientError", nil)
}

// admits reports whether member is one of the types the target can hold — the check
// jBallerina spells as matchingType.
func admits(tc semtypes.Context, target, member semtypes.SemType) bool {
	return semtypes.IsSubtype(tc, member, target)
}

// nilOnEmptyBody substitutes () for an empty payload when the target is nilable, giving the
// spec's "absent payload binds to ()" behaviour.
func nilOnEmptyBody(tc semtypes.Context, target semtypes.SemType, payload values.BalValue) values.BalValue {
	if !admits(tc, target, semtypes.NIL) {
		return payload
	}
	switch v := payload.(type) {
	case string:
		if v == "" {
			return nil
		}
	case *values.List:
		if v.Len() == 0 {
			return nil
		}
	case *values.Map:
		if v.Len() == 0 {
			return nil
		}
	}
	return payload
}

// responseContentType returns the response's raw Content-Type header value, or "" when the
// header is absent. Shared with the Response.getContentType extern.
func responseContentType(resp *values.Object) string {
	v, ok := responseHeaders(resp).Get("content-type")
	if !ok {
		return ""
	}
	list, ok := v.(*values.List)
	if !ok || list.Len() == 0 {
		return ""
	}
	raw, _ := list.Get(0).(string)
	return raw
}

// baseContentType returns the Content-Type without parameters, lower-cased and trimmed —
// jBallerina matches its patterns against the base type only.
func baseContentType(resp *values.Object) string {
	raw := responseContentType(resp)
	if idx := strings.IndexByte(raw, ';'); idx >= 0 {
		raw = raw[:idx]
	}
	return strings.ToLower(strings.TrimSpace(raw))
}

// responseBody materializes the response body bytes.
func responseBody(resp *values.Object) ([]byte, error) {
	bodyVal, _ := resp.Get("body")
	holder, ok := bodyVal.(*responseBodyHolder)
	if !ok {
		return []byte{}, nil
	}
	return holder.materialize()
}

func textValue(resp *values.Object) values.BalValue {
	body, err := responseBody(resp)
	if err != nil {
		return values.NewErrorWithMessage(err.Error())
	}
	return string(body)
}

func binaryValue(ctx *extern.Context, types *httpTypes, resp *values.Object) values.BalValue {
	body, err := responseBody(resp)
	if err != nil {
		return values.NewErrorWithMessage(err.Error())
	}
	return byteArrayValue(ctx, types, body)
}

func byteArrayValue(ctx *extern.Context, types *httpTypes, body []byte) *values.List {
	items := make([]values.BalValue, len(body))
	for i, b := range body {
		items[i] = int64(b)
	}
	return newTypedListValue(ctx.TypeEnv(), types.byteArrTy, items)
}

// formDataValue parses an application/x-www-form-urlencoded body into a map<string>.
// Repeated keys keep the last value, matching jBallerina's getFormDataMap.
func formDataValue(ctx *extern.Context, types *httpTypes, resp *values.Object) values.BalValue {
	body, err := responseBody(resp)
	if err != nil {
		return values.NewErrorWithMessage(err.Error())
	}
	parsed, parseErr := url.ParseQuery(string(body))
	if parseErr != nil {
		return payloadBindingError(parseErr.Error(), nil)
	}
	tc := ctx.TypeCtx()
	out := values.NewMap(types.mapStringTy, semtypes.ToMappingAtomicType(tc, types.mapStringTy), false, nil)
	for key, vals := range parsed {
		out.Put(tc, key, vals[len(vals)-1])
	}
	return out
}

func decodeJSONBody(ctx *extern.Context, types *httpTypes, body []byte) (values.BalValue, *values.Error) {
	dec := json.NewDecoder(bytes.NewReader(body))
	dec.UseNumber()
	var v interface{}
	if err := dec.Decode(&v); err != nil {
		return nil, values.NewErrorWithMessage("failed to parse JSON payload: " + err.Error())
	}
	return values.GoToBalValue(ctx.TypeCtx(), v, types.jsonListTy, types.jsonMapTy), nil
}
