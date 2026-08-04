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

package extern_test

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
)

// databindServer serves one canned response per path, each with the Content-Type that
// selects a particular payload builder.
func databindServer() *httptest.Server {
	type canned struct {
		status      int
		contentType string
		body        string
	}
	routes := map[string]canned{
		"/person":      {200, "application/json", `{"name": "Alice", "age": 30}`},
		"/person-hal":  {200, "application/hal+json", `{"name": "Alice", "age": 30}`},
		"/employee":    {200, "application/json", `{"name": "Alice", "address": {"city": "Colombo", "zip": 100}}`},
		"/people":      {200, "application/json", `[{"name": "Alice", "age": 30}, {"name": "Bob", "age": 25}]`},
		"/count":       {200, "application/json", `7`},
		"/flag":        {200, "application/json", `true`},
		"/broken-json": {200, "application/json", `{"name": "Alice", "age": nope}`},
		"/text":        {200, "text/plain; charset=utf-8", "plain text body"},
		"/blob":        {200, "application/octet-stream", "\x01\x02\x03"},
		"/form":        {200, "application/x-www-form-urlencoded", "a=1&b=two"},
		"/unknown":     {200, "application/vnd.custom", "opaque payload"},
		"/xml":         {200, "application/xml", "<a>1</a>"},
		"/empty":       {200, "text/plain", ""},
		"/empty-json":  {200, "application/json", ""},
		"/empty-blob":  {200, "application/octet-stream", ""},
		"/empty-form":  {200, "application/x-www-form-urlencoded", ""},
		"/bad-form":    {200, "application/x-www-form-urlencoded", "a=%zz"},
		"/moved":       {302, "text/plain", "moved body"},
		"/missing":     {404, "application/json", `{"error": "gone"}`},
		"/gone-blob":   {410, "application/octet-stream", "\x09"},
		"/boom":        {500, "text/plain", "kaboom"},
		// A valid enum member, for a target that is a proper subtype of string.
		"/colour": {200, "text/plain", "red"},
		// The same, with no Content-Type, so the builder comes from the target type.
		"/no-type-colour": {200, "", "red"},
		// Two bytes, the length a [byte, byte] tuple target accepts.
		"/blob2": {200, "application/octet-stream", "\x01\x02"},
		// 499 is nginx's client-closed-request code and has no registered reason phrase.
		"/nginx-499": {499, "text/plain", "closed"},
		// A status error carrying a JSON content type but no body at all.
		"/empty-json-401": {401, "application/json", ""},
		// An absent Content-Type sends the target type to builderFromType.
		"/no-type":       {200, "", "untyped body"},
		"/no-type-empty": {200, "", ""},
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		route, ok := routes[r.URL.Path]
		if !ok {
			w.WriteHeader(404)
			return
		}
		if route.contentType == "" {
			// Suppress Go's content sniffing so the response really has no Content-Type.
			w.Header()["Content-Type"] = nil
		} else {
			w.Header().Set("Content-Type", route.contentType)
		}
		w.WriteHeader(route.status)
		_, _ = fmt.Fprint(w, route.body)
	}))
}

// TestHttpClientDataBindLocal covers the content-type driven payload builders: json to
// records, arrays, maps and scalars; text/plain to string and byte[]; octet-stream to
// byte[]; form-urlencoded to map<string>; and the fallback for unknown media types.
func TestHttpClientDataBindLocal(t *testing.T) {
	server := databindServer()
	defer server.Close()
	runExtern(t, fileCase("http-client-databind-local-v"), newHTTPPal(rewriteClient(server.URL)), nil)
}

// TestHttpClientDataBindErrorsLocal covers the failure paths: 4xx/5xx status mapping,
// binding mismatches, malformed JSON, incompatible media types, xml responses, and the
// empty-body rules for nilable targets.
func TestHttpClientDataBindErrorsLocal(t *testing.T) {
	server := databindServer()
	defer server.Close()
	runExtern(t, fileCase("http-client-databind-errors-local-v"), newHTTPPal(rewriteClient(server.URL)), nil)
}
