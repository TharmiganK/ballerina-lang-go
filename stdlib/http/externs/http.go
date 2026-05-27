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

package http

import (
	"crypto/tls"
	"crypto/x509"
	"encoding/json"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"ballerina-lang-go/bir"
	"ballerina-lang-go/decimal"
	"ballerina-lang-go/model"
	"ballerina-lang-go/platform/pal"
	"ballerina-lang-go/runtime"
	"ballerina-lang-go/runtime/extern"
	"ballerina-lang-go/semtypes"
	"ballerina-lang-go/values"
)

var httpPackageID = model.NewPackageID(
	model.DefaultPackageIDInterner,
	model.Name("ballerina"),
	[]model.Name{model.Name("http")},
	model.Name("0.0.1"),
)

const (
	orgName    = "ballerina"
	moduleName = "http"
)

func init() {
	runtime.RegisterModuleInitializer(initHttpModule)
}

// httpTypes holds the lazily-built semtypes used by the http runtime.
// All entries are computed once on first use (so concurrent reads shouldn't be a problem);
type httpTypes struct {
	byteArrTy  semtypes.SemType
	strArrTy   semtypes.SemType
	jsonListTy semtypes.SemType
	jsonMapTy  semtypes.SemType
}

// newMappingValue builds a fresh open `map<anydata|error>` value.
func newMappingValue(tc semtypes.Context) *values.Map {
	return values.NewMap(semtypes.MAPPING, semtypes.ToMappingAtomicType(tc, semtypes.MAPPING), false, nil)
}

// newListValue builds a fresh open `(anydata|error)[]` value seeded with the
// supplied items.
func newListValue(tc semtypes.Context, items []values.BalValue) *values.List {
	return values.NewList(semtypes.LIST, semtypes.ToListAtomicType(tc, semtypes.LIST), false, nil, 0, items)
}

// newTypedListValue builds a fresh list with the supplied inherent type seeded
// with the supplied items. The atomic representation must exist; callers pass
// concrete list types built via list defs.
func newTypedListValue(tc semtypes.Context, ty semtypes.SemType, items []values.BalValue) *values.List {
	return values.NewList(ty, semtypes.ToListAtomicType(tc, ty), false, nil, 0, items)
}

func initHttpModule(rt *runtime.Runtime) {
	// Register module-level constants so BIR global-variable loads of http:LEADING
	// and http:TRAILING resolve correctly. Keys use buildGlobalVarLookupKey format:
	// org/pkg:varName = "ballerina/http:LEADING".
	runtime.RegisterModuleGlobals(rt, httpPackageID, map[string]values.BalValue{
		"ballerina/http:LEADING":  "LEADING",
		"ballerina/http:TRAILING": "TRAILING",
	})

	var (
		once  sync.Once
		types httpTypes
	)
	ensureTypes := func() {
		once.Do(func() {
			env := rt.GetTypeEnv()
			bld := semtypes.NewListDefinition()
			types.byteArrTy = bld.DefineListTypeWrappedWithEnvSemType(env, semtypes.BYTE)
			sld := semtypes.NewListDefinition()
			types.strArrTy = sld.DefineListTypeWrappedWithEnvSemType(env, semtypes.STRING)
			typCtx := semtypes.ContextFrom(env)
			jsonTy := semtypes.CreateJSON(typCtx)
			jmd := semtypes.NewMappingDefinition()
			types.jsonMapTy = jmd.DefineMappingTypeWrapped(env, nil, jsonTy)
			jld := semtypes.NewListDefinition()
			types.jsonListTy = jld.DefineListTypeWrappedWithEnvSemType(env, jsonTy)
		})
	}

	msgToBody := func(tc semtypes.Context, msg values.BalValue) ([]byte, string) {
		ensureTypes()
		switch v := msg.(type) {
		case string:
			return []byte(v), "text/plain"
		case *values.List:
			if v.Type != nil && semtypes.IsSubtype(tc, v.Type, types.byteArrTy) {
				if b, ok := listToBytes(v); ok {
					return b, "application/octet-stream"
				}
			}
			b, err := toJSONBytes(v)
			if err != nil {
				return nil, "json_error"
			}
			return b, "application/json"
		default:
			b, err := toJSONBytes(v)
			if err != nil {
				return nil, "json_error"
			}
			return b, "application/json"
		}
	}
	execBody := func(ctx *extern.Context, verb string, args []values.BalValue) (values.BalValue, error) {
		self := args[0].(*values.Object)
		path := args[1].(string)
		var body []byte
		contentType := ""
		if len(args) > 2 && args[2] != nil {
			body, contentType = msgToBody(ctx.TypeCtx, args[2])
			if body == nil && contentType == "json_error" {
				return values.NewErrorWithMessage("failed to serialize body to JSON"), nil
			}
		}
		var reqHeaders map[string][]string
		if len(args) > 3 {
			reqHeaders = extractHeaders(args[3])
			for hdrKey, hdrVals := range reqHeaders {
				if strings.EqualFold(hdrKey, "content-type") && len(hdrVals) > 0 {
					contentType = hdrVals[0]
					break
				}
			}
		}
		if len(args) > 4 {
			if mt, ok := args[4].(string); ok && mt != "" {
				contentType = mt
			}
		}
		urlVal, _ := self.Get("url")
		clientHandle, _ := self.Get("$httpClient")
		statusCode, respHeaders, respBody, err := clientHandle.(pal.HTTPClient).Execute(verb, urlVal.(string)+path, body, contentType, reqHeaders)
		if err != nil {
			return values.NewErrorWithMessage(err.Error()), nil
		}
		return buildResponse(ctx.TypeCtx, statusCode, respHeaders, respBody), nil
	}

	// Remote method name uses the "$remote$" prefix (model.RemoteMethodName).
	// The BIR gen emits `callInfo.Name = "$remote$get"` for c->get(...), which
	// resolveObjectMethod then looks up in the object's methodKeys map.
	clientClassDef := &bir.BIRClassDef{
		Name:      model.Name("Client"),
		LookupKey: "ballerina/http:Client",
		Fields: []bir.ObjectField{
			{Name: "url", Ty: semtypes.STRING},
			{Name: "timeout", Ty: semtypes.DECIMAL},
			{Name: "followRedirects", Ty: semtypes.Union(semtypes.MAPPING, semtypes.NIL)},
			{Name: "httpVersion", Ty: semtypes.STRING},
		},
		VTable: map[string]*bir.BIRFunction{
			"init":            {FunctionLookupKey: "ballerina/http:Client.init"},
			"initNative":      {FunctionLookupKey: "ballerina/http:Client.initNative"},
			"$remote$get":     {FunctionLookupKey: "ballerina/http:Client.$remote$get"},
			"$remote$post":    {FunctionLookupKey: "ballerina/http:Client.$remote$post"},
			"$remote$head":    {FunctionLookupKey: "ballerina/http:Client.$remote$head"},
			"$remote$options": {FunctionLookupKey: "ballerina/http:Client.$remote$options"},
			"$remote$put":     {FunctionLookupKey: "ballerina/http:Client.$remote$put"},
			"$remote$patch":   {FunctionLookupKey: "ballerina/http:Client.$remote$patch"},
			"$remote$delete":  {FunctionLookupKey: "ballerina/http:Client.$remote$delete"},
			"$remote$execute": {FunctionLookupKey: "ballerina/http:Client.$remote$execute"},
		},
	}
	runtime.RegisterExternClassDef(rt, clientClassDef)

	// Default lambda for config param: called as $Client.init$default$1(url) → returns {}.
	// Receives [url] (the preceding arg) and ignores it; the default is always {}.
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.init$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return newMappingValue(ctx.TypeCtx), nil
		})

	// Default lambda for headers param: called as $Client.get$default$1(path) → returns () = nil.
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.get$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return nil, nil
		})
	runtime.RegisterExternFunction(rt, orgName, moduleName, "parseHeader",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			input, ok := args[0].(string)
			if !ok {
				return nil, fmt.Errorf("parseHeader: expected string argument")
			}
			result, err := parseHeader(ctx.TypeCtx, input)
			if err != nil {
				return values.NewErrorWithMessage(err.Error()), nil
			}
			return result, nil
		})

	// initNative is the extern called by the Ballerina Client.init wrapper.
	// The Ballerina wrapper handles default-expansion of the config parameter,
	// so args are always [self, url, config].
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.initNative",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			url := args[1].(string)

			timeout := decimal.FromInt64(30)
			var followRedirects pal.FollowRedirects // Enabled=false by default (Ballerina spec)
			httpVersion := "2.0"

			var tlsCfg pal.TLSConfig
			if cfg, ok := args[2].(*values.Map); ok {
					if v, ok := cfg.Get("timeout"); ok {
						if d, ok := v.(*decimal.Decimal); ok {
							timeout = d
						}
					}
					if v, ok := cfg.Get("followRedirects"); ok {
						if frMap, ok := v.(*values.Map); ok {
							if ev, ok := frMap.Get("enabled"); ok {
								if b, ok := ev.(bool); ok {
									followRedirects.Enabled = b
								}
							}
							followRedirects.MaxCount = 5
							if mv, ok := frMap.Get("maxCount"); ok {
								if n, ok := mv.(int64); ok {
									followRedirects.MaxCount = int(n)
								}
							}
							if av, ok := frMap.Get("allowAuthHeaders"); ok {
								if b, ok := av.(bool); ok {
									followRedirects.AllowAuthHeaders = b
								}
							}
						}
					}
					if v, ok := cfg.Get("httpVersion"); ok {
						if s, ok := v.(string); ok {
							httpVersion = s
						}
					}
					if ss, ok := cfg.Get("secureSocket"); ok {
						if ssMap, ok := ss.(*values.Map); ok {
							if v, ok := ssMap.Get("enable"); ok {
								if b, ok := v.(bool); ok && !b {
									tlsCfg.InsecureSkipVerify = true
								}
							}
							if v, ok := ssMap.Get("verifyHostName"); ok {
								if b, ok := v.(bool); ok && !b {
									tlsCfg.InsecureSkipVerify = true
								}
							}
							if v, ok := ssMap.Get("cert"); ok {
								if certPath, ok := v.(string); ok && certPath != "" {
									data, err := rt.Platform().FS.ReadFile(certPath)
									if err != nil {
										return values.NewErrorWithMessage("secureSocket.cert: " + err.Error()), nil
									}
									tlsCfg.CACertPEM = data
								}
							}
							if v, ok := ssMap.Get("key"); ok {
								if keyMap, ok := v.(*values.Map); ok {
									if cv, ok := keyMap.Get("certFile"); ok {
										if p, ok := cv.(string); ok && p != "" {
											data, err := rt.Platform().FS.ReadFile(p)
											if err != nil {
												return values.NewErrorWithMessage("secureSocket.key.certFile: " + err.Error()), nil
											}
											tlsCfg.ClientCertPEM = data
										}
									}
									if kv, ok := keyMap.Get("keyFile"); ok {
										if p, ok := kv.(string); ok && p != "" {
											data, err := rt.Platform().FS.ReadFile(p)
											if err != nil {
												return values.NewErrorWithMessage("secureSocket.key.keyFile: " + err.Error()), nil
											}
											tlsCfg.ClientKeyPEM = data
										}
									}
									// keyPassword: accepted at compile time, ignored at runtime
								}
							}
							if v, ok := ssMap.Get("serverName"); ok {
								if s, ok := v.(string); ok && s != "" {
									tlsCfg.ServerName = s
								}
							}
							if v, ok := ssMap.Get("shareSession"); ok {
								if b, ok := v.(bool); ok && !b {
									tlsCfg.DisableSessionTickets = true
								}
							}
							if v, ok := ssMap.Get("handshakeTimeout"); ok {
								if d, ok := v.(*decimal.Decimal); ok {
									tlsCfg.HandshakeTimeout = decimalToDuration(d)
								}
							}
							if v, ok := ssMap.Get("ciphers"); ok {
								if list, ok := v.(*values.List); ok {
									for i := 0; i < list.Len(); i++ {
										if name, ok := list.Get(i).(string); ok {
											tlsCfg.CipherSuiteNames = append(tlsCfg.CipherSuiteNames, name)
										}
									}
								}
							}
							if v, ok := ssMap.Get("protocol"); ok {
								if protoMap, ok := v.(*values.Map); ok {
									if vv, ok := protoMap.Get("versions"); ok {
										if list, ok := vv.(*values.List); ok {
											tlsVersionMap := map[string]uint16{
												"TLSv1.0": 0x0301,
												"TLSv1.1": 0x0302,
												"TLSv1.2": 0x0303,
												"TLSv1.3": 0x0304,
											}
											for i := 0; i < list.Len(); i++ {
												if s, ok := list.Get(i).(string); ok {
													if ver, found := tlsVersionMap[s]; found {
														if tlsCfg.MinVersion == 0 || ver < tlsCfg.MinVersion {
															tlsCfg.MinVersion = ver
														}
														if ver > tlsCfg.MaxVersion {
															tlsCfg.MaxVersion = ver
														}
													}
												}
											}
										}
									}
								}
							}
							// certValidation/sessionTimeout: accepted at compile time, not supported at runtime
						}
					}
				}
			httpClient := rt.Platform().HTTP.NewClient(pal.ClientConfig{
				Timeout:         decimalToDuration(timeout),
				FollowRedirects: followRedirects,
				HTTPVersion:     httpVersion,
				TLS:             tlsCfg,
			})
			self.Put("url", url)
			self.Put("timeout", timeout)
			self.Put("followRedirects", nil)
			self.Put("httpVersion", httpVersion)
			self.Put("$httpClient", httpClient)
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$get",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			path := args[1].(string)

			var reqHeaders map[string][]string
			if len(args) > 2 {
				reqHeaders = extractHeaders(args[2])
			}

			urlVal, _ := self.Get("url")
			clientHandle, _ := self.Get("$httpClient")
			statusCode, respHeaders, body, err := clientHandle.(pal.HTTPClient).Execute("GET", urlVal.(string)+path, nil, "", reqHeaders)
			if err != nil {
				return values.NewErrorWithMessage(err.Error()), nil
			}
			return buildResponse(ctx.TypeCtx, statusCode, respHeaders, body), nil
		})

	// Default lambdas for post optional params (both return nil = Ballerina ())
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.post$default$2",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.post$default$3",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$post",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return execBody(ctx, "POST", args)
		})

	// head: body-less, like get
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.head$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$head",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			path := args[1].(string)
			var reqHeaders map[string][]string
			if len(args) > 2 {
				reqHeaders = extractHeaders(args[2])
			}
			urlVal, _ := self.Get("url")
			clientHandle, _ := self.Get("$httpClient")
			statusCode, respHeaders, body, err := clientHandle.(pal.HTTPClient).Execute("HEAD", urlVal.(string)+path, nil, "", reqHeaders)
			if err != nil {
				return values.NewErrorWithMessage(err.Error()), nil
			}
			return buildResponse(ctx.TypeCtx, statusCode, respHeaders, body), nil
		})

	// options: body-less, like get
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.options$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$options",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			path := args[1].(string)
			var reqHeaders map[string][]string
			if len(args) > 2 {
				reqHeaders = extractHeaders(args[2])
			}
			urlVal, _ := self.Get("url")
			clientHandle, _ := self.Get("$httpClient")
			statusCode, respHeaders, body, err := clientHandle.(pal.HTTPClient).Execute("OPTIONS", urlVal.(string)+path, nil, "", reqHeaders)
			if err != nil {
				return values.NewErrorWithMessage(err.Error()), nil
			}
			return buildResponse(ctx.TypeCtx, statusCode, respHeaders, body), nil
		})

	// put: body required, like post
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.put$default$2",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.put$default$3",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$put",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return execBody(ctx, "PUT", args)
		})

	// patch: body required, like post
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.patch$default$2",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.patch$default$3",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$patch",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return execBody(ctx, "PATCH", args)
		})

	// delete: message is optional (defaults to nil = empty body)
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.delete$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.delete$default$2",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.delete$default$3",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$delete",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return execBody(ctx, "DELETE", args)
		})

	// execute: args = [self, httpVerb, path, message, headers?, mediaType?]
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.execute$default$3",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Client.execute$default$4",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) { return nil, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Client.$remote$execute",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			verb := args[1].(string)
			path := args[2].(string)

			var body []byte
			contentType := ""
			if len(args) > 3 && args[3] != nil {
				body, contentType = msgToBody(ctx.TypeCtx, args[3])
				if body == nil && contentType == "json_error" {
					return values.NewErrorWithMessage("failed to serialize body to JSON"), nil
				}
			}

			var reqHeaders map[string][]string
			if len(args) > 4 {
				reqHeaders = extractHeaders(args[4])
				for hdrKey, hdrVals := range reqHeaders {
					if strings.EqualFold(hdrKey, "content-type") && len(hdrVals) > 0 {
						contentType = hdrVals[0]
						break
					}
				}
			}
			if len(args) > 5 {
				if mt, ok := args[5].(string); ok && mt != "" {
					contentType = mt
				}
			}

			urlVal, _ := self.Get("url")
			clientHandle, _ := self.Get("$httpClient")
			statusCode, respHeaders, respBody, err := clientHandle.(pal.HTTPClient).Execute(verb, urlVal.(string)+path, body, contentType, reqHeaders)
			if err != nil {
				return values.NewErrorWithMessage(err.Error()), nil
			}
			return buildResponse(ctx.TypeCtx, statusCode, respHeaders, respBody), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.getTextPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			body, _ := self.Get("body")
			return body, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.getJsonPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			ensureTypes()
			self := args[0].(*values.Object)
			bodyVal, _ := self.Get("body")
			body := bodyVal.(string)
			dec := json.NewDecoder(strings.NewReader(body))
			dec.UseNumber()
			var v interface{}
			if err := dec.Decode(&v); err != nil {
				return values.NewErrorWithMessage("failed to parse JSON payload: " + err.Error()), nil
			}
			return goToBalValue(ctx.TypeCtx, v, types.jsonListTy, types.jsonMapTy), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.getBinaryPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			ensureTypes()
			self := args[0].(*values.Object)
			bodyVal, _ := self.Get("body")
			body := bodyVal.(string)
			raw := []byte(body)
			items := make([]values.BalValue, len(raw))
			for i, b := range raw {
				items[i] = int64(b)
			}
			return newTypedListValue(ctx.TypeCtx, types.byteArrTy, items), nil
		})

	// Default lambdas for position param (all return "LEADING")
	leading := values.BalValue("LEADING")
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Response.hasHeader$default$1",
		func(_ *extern.Context, _ []values.BalValue) (values.BalValue, error) { return leading, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Response.getHeader$default$1",
		func(_ *extern.Context, _ []values.BalValue) (values.BalValue, error) { return leading, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Response.getHeaders$default$1",
		func(_ *extern.Context, _ []values.BalValue) (values.BalValue, error) { return leading, nil })
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Response.getHeaderNames$default$0",
		func(_ *extern.Context, _ []values.BalValue) (values.BalValue, error) { return leading, nil })

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.hasHeader",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			// args[2] is position — ignored
			_, ok := responseHeaders(self).Get(name)
			return ok, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.getHeader",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			v, ok := responseHeaders(self).Get(name)
			if !ok {
				return values.NewErrorWithMessage("header not found: " + name), nil
			}
			list := v.(*values.List)
			if list.Len() == 0 {
				return values.NewErrorWithMessage("header has no values: " + name), nil
			}
			return list.Get(0), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.getHeaders",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			v, ok := responseHeaders(self).Get(name)
			if !ok {
				return values.NewErrorWithMessage("header not found: " + name), nil
			}
			return v.(*values.List), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.getHeaderNames",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			ensureTypes()
			self := args[0].(*values.Object)
			keys := responseHeaders(self).Keys()
			items := make([]values.BalValue, len(keys))
			for i, k := range keys {
				items[i] = k
			}
			return newTypedListValue(ctx.TypeCtx, types.strArrTy, items), nil
		})

	// Register response class def so `new http:Response()` works in server code.
	responseClassDef := &bir.BIRClassDef{
		Name:      model.Name("Response"),
		LookupKey: "ballerina/http:Response",
		Fields: []bir.ObjectField{
			{Name: "statusCode", Ty: semtypes.INT},
		},
		VTable: map[string]*bir.BIRFunction{
			"init":             {FunctionLookupKey: "ballerina/http:Response.init"},
			"setTextPayload":   {FunctionLookupKey: "ballerina/http:Response.setTextPayload"},
			"setJsonPayload":   {FunctionLookupKey: "ballerina/http:Response.setJsonPayload"},
			"setBinaryPayload": {FunctionLookupKey: "ballerina/http:Response.setBinaryPayload"},
			"setHeader":        {FunctionLookupKey: "ballerina/http:Response.setHeader"},
			"setStatusCode":    {FunctionLookupKey: "ballerina/http:Response.setStatusCode"},
			"getTextPayload":   {FunctionLookupKey: "ballerina/http:Response.getTextPayload"},
			"getJsonPayload":   {FunctionLookupKey: "ballerina/http:Response.getJsonPayload"},
			"getBinaryPayload": {FunctionLookupKey: "ballerina/http:Response.getBinaryPayload"},
			"hasHeader":        {FunctionLookupKey: "ballerina/http:Response.hasHeader"},
			"getHeader":        {FunctionLookupKey: "ballerina/http:Response.getHeader"},
			"getHeaders":       {FunctionLookupKey: "ballerina/http:Response.getHeaders"},
			"getHeaderNames":   {FunctionLookupKey: "ballerina/http:Response.getHeaderNames"},
		},
	}
	runtime.RegisterExternClassDef(rt, responseClassDef)

	// Response write methods.
	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.init",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			self.Put("statusCode", int64(200))
			self.Put("$headers", newMappingValue(ctx.TypeCtx))
			self.Put("body", "")
			self.Put("$contentType", "")
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.setTextPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			self.Put("body", args[1].(string))
			self.Put("$contentType", "text/plain")
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.setJsonPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			b, err := toJSONBytes(args[1])
			if err != nil {
				return values.NewErrorWithMessage("setJsonPayload: " + err.Error()), nil
			}
			self.Put("body", string(b))
			self.Put("$contentType", "application/json")
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.setBinaryPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			list, ok := args[1].(*values.List)
			if !ok {
				return values.NewErrorWithMessage("setBinaryPayload: expected byte[]"), nil
			}
			b, ok := listToBytes(list)
			if !ok {
				return values.NewErrorWithMessage("setBinaryPayload: invalid byte value"), nil
			}
			self.Put("body", string(b))
			self.Put("$contentType", "application/octet-stream")
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.setHeader",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			val := args[2].(string)
			headers := responseHeaders(self)
			headers.Put(ctx.TypeCtx, name, newListValue(ctx.TypeCtx, []values.BalValue{val}))
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Response.setStatusCode",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			self.Put("statusCode", args[1].(int64))
			return nil, nil
		})

	// Request class def and extern functions.
	requestClassDef := &bir.BIRClassDef{
		Name:      model.Name("Request"),
		LookupKey: "ballerina/http:Request",
		Fields: []bir.ObjectField{
			{Name: "rawPath", Ty: semtypes.STRING},
			{Name: "method", Ty: semtypes.STRING},
			{Name: "httpVersion", Ty: semtypes.STRING},
		},
		VTable: map[string]*bir.BIRFunction{
			"getTextPayload":     {FunctionLookupKey: "ballerina/http:Request.getTextPayload"},
			"getJsonPayload":     {FunctionLookupKey: "ballerina/http:Request.getJsonPayload"},
			"getBinaryPayload":   {FunctionLookupKey: "ballerina/http:Request.getBinaryPayload"},
			"getHeader":          {FunctionLookupKey: "ballerina/http:Request.getHeader"},
			"getHeaders":         {FunctionLookupKey: "ballerina/http:Request.getHeaders"},
			"hasHeader":          {FunctionLookupKey: "ballerina/http:Request.hasHeader"},
			"getQueryParams":     {FunctionLookupKey: "ballerina/http:Request.getQueryParams"},
			"getQueryParamValue": {FunctionLookupKey: "ballerina/http:Request.getQueryParamValue"},
		},
	}
	runtime.RegisterExternClassDef(rt, requestClassDef)

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getTextPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			body, _ := self.Get("$body")
			return body, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getJsonPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			ensureTypes()
			self := args[0].(*values.Object)
			bodyVal, _ := self.Get("$body")
			body, _ := bodyVal.(string)
			dec := json.NewDecoder(strings.NewReader(body))
			dec.UseNumber()
			var v interface{}
			if err := dec.Decode(&v); err != nil {
				return values.NewErrorWithMessage("getJsonPayload: " + err.Error()), nil
			}
			return goToBalValue(ctx.TypeCtx, v, types.jsonListTy, types.jsonMapTy), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getBinaryPayload",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			ensureTypes()
			self := args[0].(*values.Object)
			bodyVal, _ := self.Get("$body")
			body, _ := bodyVal.(string)
			raw := []byte(body)
			items := make([]values.BalValue, len(raw))
			for i, b := range raw {
				items[i] = int64(b)
			}
			return newTypedListValue(ctx.TypeCtx, types.byteArrTy, items), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getHeader",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			hdrsVal, _ := self.Get("$headers")
			hdrs, ok := hdrsVal.(*values.Map)
			if !ok {
				return values.NewErrorWithMessage("header not found: " + name), nil
			}
			v, ok := hdrs.Get(name)
			if !ok {
				return values.NewErrorWithMessage("header not found: " + name), nil
			}
			list := v.(*values.List)
			if list.Len() == 0 {
				return values.NewErrorWithMessage("header has no values: " + name), nil
			}
			return list.Get(0), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getHeaders",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			hdrsVal, _ := self.Get("$headers")
			hdrs, ok := hdrsVal.(*values.Map)
			if !ok {
				return values.NewErrorWithMessage("header not found: " + name), nil
			}
			v, ok := hdrs.Get(name)
			if !ok {
				return values.NewErrorWithMessage("header not found: " + name), nil
			}
			return v.(*values.List), nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.hasHeader",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			name := strings.ToLower(args[1].(string))
			hdrsVal, _ := self.Get("$headers")
			hdrs, ok := hdrsVal.(*values.Map)
			if !ok {
				return false, nil
			}
			_, ok = hdrs.Get(name)
			return ok, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getQueryParams",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			ensureTypes()
			self := args[0].(*values.Object)
			queryStrVal, _ := self.Get("$queryStr")
			queryStr, _ := queryStrVal.(string)
			parsed, _ := url.ParseQuery(queryStr)
			m := newMappingValue(ctx.TypeCtx)
			for k, vals := range parsed {
				items := make([]values.BalValue, len(vals))
				for i, v := range vals {
					items[i] = v
				}
				m.Put(ctx.TypeCtx, k, newTypedListValue(ctx.TypeCtx, types.strArrTy, items))
			}
			return m, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Request.getQueryParamValue",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			paramName := args[1].(string)
			queryStrVal, _ := self.Get("$queryStr")
			queryStr, _ := queryStrVal.(string)
			parsed, _ := url.ParseQuery(queryStr)
			vals, ok := parsed[paramName]
			if !ok || len(vals) == 0 {
				return nil, nil
			}
			return vals[0], nil
		})

	// Listener class def and extern functions.
	listenerClassDef := &bir.BIRClassDef{
		Name:      model.Name("Listener"),
		LookupKey: "ballerina/http:Listener",
		Fields:    []bir.ObjectField{},
		VTable: map[string]*bir.BIRFunction{
			"init":          {FunctionLookupKey: "ballerina/http:Listener.init"},
			"attach":        {FunctionLookupKey: "ballerina/http:Listener.attach"},
			"detach":        {FunctionLookupKey: "ballerina/http:Listener.detach"},
			"start":         {FunctionLookupKey: "ballerina/http:Listener.start"},
			"gracefulStop":  {FunctionLookupKey: "ballerina/http:Listener.gracefulStop"},
			"immediateStop": {FunctionLookupKey: "ballerina/http:Listener.immediateStop"},
		},
	}
	runtime.RegisterExternClassDef(rt, listenerClassDef)

	// Listener default lambdas.
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Listener.init$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return newMappingValue(ctx.TypeCtx), nil
		})
	runtime.RegisterExternFunction(rt, orgName, moduleName, "$Listener.attach$default$1",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Listener.init",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			port := int(args[1].(int64))
			state := &listenerState{
				host:    "0.0.0.0",
				port:    port,
				timeout: 60 * time.Second,
			}
			if len(args) > 2 {
				if cfg, ok := args[2].(*values.Map); ok {
					if v, ok := cfg.Get("host"); ok {
						if s, ok := v.(string); ok && s != "" {
							state.host = s
						}
					}
					if v, ok := cfg.Get("timeout"); ok {
						if d, ok := v.(*decimal.Decimal); ok {
							state.timeout = decimalToDuration(d)
						}
					}
					if v, ok := cfg.Get("secureSocket"); ok {
						if ssMap, ok := v.(*values.Map); ok {
							tlsCfg, err := buildListenerTLSConfig(ssMap, rt.Platform().FS)
							if err != nil {
								return values.NewErrorWithMessage("Listener.init secureSocket: " + err.Error()), nil
							}
							state.tlsCfg = tlsCfg
						}
					}
				}
			}
			self.Put("$state", state)
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Listener.attach",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			svcObj, ok := args[1].(*values.Object)
			if !ok {
				return values.NewErrorWithMessage("Listener.attach: expected service object"), nil
			}
			basePath := extractAttachPath(args[2])
			stateVal, _ := self.Get("$state")
			state := stateVal.(*listenerState)

			if msg := validateServiceForHTTP(svcObj); msg != "" {
				return values.NewErrorWithMessage("Listener.attach: " + msg), nil
			}

			state.mu.Lock()
			entry := &serviceEntry{basePath: basePath, svcObj: svcObj}
			state.services = append(state.services, entry)
			sort.Slice(state.services, func(i, j int) bool {
				return len(state.services[i].basePath) > len(state.services[j].basePath)
			})
			alreadyStarted := state.server != nil
			state.mu.Unlock()

			if !alreadyStarted {
				server, err := startHTTPServer(rt, state, func() { rt.ListenerDone() })
				if err != nil {
					return values.NewErrorWithMessage("Listener.attach: " + err.Error()), nil
				}
				state.mu.Lock()
				state.server = server
				state.mu.Unlock()
				rt.RegisterActiveListener(func() { _ = server.Close() })
			}
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Listener.detach",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			svcObj := args[1].(*values.Object)
			stateVal, _ := self.Get("$state")
			state := stateVal.(*listenerState)
			state.mu.Lock()
			defer state.mu.Unlock()
			for i, e := range state.services {
				if e.svcObj == svcObj {
					state.services = append(state.services[:i], state.services[i+1:]...)
					break
				}
			}
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Listener.start",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Listener.gracefulStop",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			stateVal, ok := self.Get("$state")
			if !ok {
				return nil, nil
			}
			state := stateVal.(*listenerState)
			if state.server != nil {
				_ = state.server.Close()
			}
			return nil, nil
		})

	runtime.RegisterExternFunction(rt, orgName, moduleName, "Listener.immediateStop",
		func(ctx *extern.Context, args []values.BalValue) (values.BalValue, error) {
			self := args[0].(*values.Object)
			stateVal, ok := self.Get("$state")
			if !ok {
				return nil, nil
			}
			state := stateVal.(*listenerState)
			if state.server != nil {
				_ = state.server.Close()
			}
			return nil, nil
		})
}

// splitOutsideQuotes splits s on every occurrence of sep that is not inside a
// double-quoted string (RFC 7230 §3.2.6 quoted-string), honouring backslash escapes.
func splitOutsideQuotes(s string, sep byte) []string {
	var out []string
	inQuote := false
	start := 0
	for i := 0; i < len(s); i++ {
		c := s[i]
		switch {
		case c == '\\' && inQuote && i+1 < len(s):
			i++ // skip the escaped character
		case c == '"':
			inQuote = !inQuote
		case c == sep && !inQuote:
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	return append(out, s[start:])
}

func parseHeader(tc semtypes.Context, input string) (*values.List, error) {
	segments := splitOutsideQuotes(input, ',')
	list := newListValue(tc, nil)
	for _, seg := range segments {
		seg = strings.TrimSpace(seg)
		if seg == "" {
			return nil, fmt.Errorf("invalid header value: empty segment")
		}
		parts := splitOutsideQuotes(seg, ';')
		headerVal := strings.TrimSpace(parts[0])
		if headerVal == "" {
			return nil, fmt.Errorf("invalid header value: missing value before parameters")
		}
		params := newMappingValue(tc)
		for _, param := range parts[1:] {
			param = strings.TrimSpace(param)
			if param == "" {
				continue
			}
			eqIdx := strings.IndexByte(param, '=')
			if eqIdx < 0 {
				params.Put(tc, strings.ToLower(param), "")
				continue
			}
			key := strings.ToLower(strings.TrimSpace(param[:eqIdx]))
			val := strings.TrimSpace(param[eqIdx+1:])
			if len(val) >= 2 && val[0] == '"' && val[len(val)-1] == '"' {
				val = val[1 : len(val)-1]
			}
			params.Put(tc, key, val)
		}
		entry := newMappingValue(tc)
		entry.Put(tc, "value", headerVal)
		entry.Put(tc, "params", params)
		list.Append(tc, entry)
	}
	return list, nil
}

func decimalToDuration(d *decimal.Decimal) time.Duration {
	return time.Duration(d.Float64() * float64(time.Second))
}

// extractHeaders converts a Ballerina map<string|string[]>? value to Go request headers.
func extractHeaders(arg values.BalValue) map[string][]string {
	if arg == nil {
		return nil
	}
	hdrMap, ok := arg.(*values.Map)
	if !ok {
		return nil
	}
	result := make(map[string][]string, hdrMap.Len())
	for _, key := range hdrMap.Keys() {
		val, _ := hdrMap.Get(key)
		switch v := val.(type) {
		case string:
			result[key] = []string{v}
		case *values.List:
			strs := make([]string, v.Len())
			for i := range v.Len() {
				if s, ok := v.Get(i).(string); ok {
					strs[i] = s
				}
			}
			result[key] = strs
		}
	}
	return result
}

// buildResponse constructs a Ballerina Response object from HTTP response data.
// All header values are stored as *values.List under the internal "$headers" key.
func buildResponse(tc semtypes.Context, statusCode int, respHeaders map[string][]string, body []byte) *values.Object {
	headersMap := newMappingValue(tc)
	for k, vals := range respHeaders {
		items := make([]values.BalValue, len(vals))
		for i, v := range vals {
			items[i] = v
		}
		headersMap.Put(tc, strings.ToLower(k), newListValue(tc, items))
	}
	return values.NewObject(
		semtypes.OBJECT,
		map[string]values.BalValue{
			"statusCode": int64(statusCode),
			"$headers":   headersMap,
			"body":       string(body),
		},
		map[string]string{
			"getTextPayload":   "ballerina/http:Response.getTextPayload",
			"getJsonPayload":   "ballerina/http:Response.getJsonPayload",
			"getBinaryPayload": "ballerina/http:Response.getBinaryPayload",
			"hasHeader":        "ballerina/http:Response.hasHeader",
			"getHeader":        "ballerina/http:Response.getHeader",
			"getHeaders":       "ballerina/http:Response.getHeaders",
			"getHeaderNames":   "ballerina/http:Response.getHeaderNames",
		},
		nil,
	)
}

// responseHeaders returns the internal header map stored on a Response object.
func responseHeaders(self *values.Object) *values.Map {
	h, _ := self.Get("$headers")
	return h.(*values.Map)
}

// listToBytes converts a Ballerina byte[] (List of int64 in 0–255) to []byte.
// Returns (nil, false) if any element is not an integer in the byte range,
// indicating the list should be treated as a JSON array instead.
func listToBytes(list *values.List) ([]byte, bool) {
	b := make([]byte, list.Len())
	for i := range list.Len() {
		n, ok := list.Get(i).(int64)
		if !ok || n < 0 || n > 255 {
			return nil, false
		}
		b[i] = byte(n)
	}
	return b, true
}

// balToGoJSON converts a Ballerina value to a Go value suitable for json.Marshal.
// Handles all Ballerina json-compatible types: nil, bool, int, float, decimal, string, map, list.
func balToGoJSON(v values.BalValue) any {
	switch t := v.(type) {
	case nil:
		return nil
	case bool:
		return t
	case int64:
		return t
	case float64:
		return t
	case *decimal.Decimal:
		// Emit the decimal128 string verbatim as a JSON number so the full
		// precision of the value is preserved — going through Float64() truncates
		// past ~17 significant digits.
		return json.RawMessage(t.String())
	case string:
		return t
	case *values.Map:
		m := make(map[string]any, t.Len())
		for _, k := range t.Keys() {
			val, _ := t.Get(k)
			m[k] = balToGoJSON(val)
		}
		return m
	case *values.List:
		s := make([]any, t.Len())
		for i := range t.Len() {
			s[i] = balToGoJSON(t.Get(i))
		}
		return s
	default:
		return nil
	}
}

// toJSONBytes serializes a Ballerina value to JSON bytes.
func toJSONBytes(v values.BalValue) ([]byte, error) {
	return json.Marshal(balToGoJSON(v))
}

// listenerState holds per-listener runtime state stored in the $state field.
type listenerState struct {
	host     string
	port     int
	timeout  time.Duration
	tlsCfg   *tls.Config
	mu       sync.RWMutex
	services []*serviceEntry
	server   *http.Server
}

type serviceEntry struct {
	basePath string
	svcObj   *values.Object
}

// extractAttachPath converts the Ballerina attach-point value to a base path string.
// () → "/", "foo" → "/foo", ["a","b"] → "/a/b"
func extractAttachPath(v values.BalValue) string {
	if v == nil {
		return "/"
	}
	switch val := v.(type) {
	case string:
		if val == "" {
			return "/"
		}
		if !strings.HasPrefix(val, "/") {
			return "/" + val
		}
		return val
	case *values.List:
		parts := make([]string, val.Len())
		for i := range val.Len() {
			if s, ok := val.Get(i).(string); ok {
				parts[i] = s
			}
		}
		return "/" + strings.Join(parts, "/")
	}
	return "/"
}

// buildListenerTLSConfig builds a *tls.Config from a ListenerSecureSocket map.
func buildListenerTLSConfig(ssMap *values.Map, fs pal.FS) (*tls.Config, error) {
	keyVal, ok := ssMap.Get("key")
	if !ok {
		return nil, fmt.Errorf("secureSocket.key is required")
	}
	keyMap, ok := keyVal.(*values.Map)
	if !ok {
		return nil, fmt.Errorf("secureSocket.key must be a CertKey record")
	}

	certFileVal, _ := keyMap.Get("certFile")
	keyFileVal, _ := keyMap.Get("keyFile")
	certFilePath, _ := certFileVal.(string)
	keyFilePath, _ := keyFileVal.(string)

	certPEM, err := fs.ReadFile(certFilePath)
	if err != nil {
		return nil, fmt.Errorf("key.certFile: %w", err)
	}
	keyPEM, err := fs.ReadFile(keyFilePath)
	if err != nil {
		return nil, fmt.Errorf("key.keyFile: %w", err)
	}
	cert, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		return nil, fmt.Errorf("X509KeyPair: %w", err)
	}

	tlsCfg := &tls.Config{Certificates: []tls.Certificate{cert}}

	// mTLS: client certificate verification
	if v, ok := ssMap.Get("mutualSsl"); ok {
		if b, ok := v.(bool); ok && b {
			if caCertPathVal, ok := ssMap.Get("cert"); ok {
				if caCertPath, ok := caCertPathVal.(string); ok && caCertPath != "" {
					caCertPEM, err := fs.ReadFile(caCertPath)
					if err != nil {
						return nil, fmt.Errorf("secureSocket.cert (CA): %w", err)
					}
					pool := x509.NewCertPool()
					if !pool.AppendCertsFromPEM(caCertPEM) {
						return nil, fmt.Errorf("failed to parse CA certificate")
					}
					tlsCfg.ClientCAs = pool
					tlsCfg.ClientAuth = tls.RequireAndVerifyClientCert
				}
			}
		}
	}

	// TLS version
	if v, ok := ssMap.Get("protocol"); ok {
		if list, ok := v.(*values.List); ok {
			tlsVersionMap := map[string]uint16{
				"TLSv1.0": 0x0301, "TLSv1.1": 0x0302,
				"TLSv1.2": 0x0303, "TLSv1.3": 0x0304,
			}
			for i := range list.Len() {
				if s, ok := list.Get(i).(string); ok {
					if ver, found := tlsVersionMap[s]; found {
						if tlsCfg.MinVersion == 0 || ver < tlsCfg.MinVersion {
							tlsCfg.MinVersion = ver
						}
						if ver > tlsCfg.MaxVersion {
							tlsCfg.MaxVersion = ver
						}
					}
				}
			}
		}
	}

	// Cipher suites
	if v, ok := ssMap.Get("ciphers"); ok {
		if list, ok := v.(*values.List); ok {
			allSuites := append(tls.CipherSuites(), tls.InsecureCipherSuites()...)
			nameToID := make(map[string]uint16, len(allSuites))
			for _, cs := range allSuites {
				nameToID[cs.Name] = cs.ID
			}
			for i := range list.Len() {
				if s, ok := list.Get(i).(string); ok {
					if id, found := nameToID[s]; found {
						tlsCfg.CipherSuites = append(tlsCfg.CipherSuites, id)
					}
				}
			}
		}
	}

	// Session tickets
	if v, ok := ssMap.Get("shareSession"); ok {
		if b, ok := v.(bool); ok && !b {
			tlsCfg.SessionTicketsDisabled = true
		}
	}

	return tlsCfg, nil
}

// validateServiceForHTTP rejects service objects that contain remote methods, which are
// not supported for HTTP dispatch. Normal and resource methods are allowed.
// Returns a non-empty error message if validation fails.
func validateServiceForHTTP(svcObj *values.Object) string {
	if svcObj.HasRemoteMethods() {
		return "service object must not have remote methods"
	}
	return ""
}

// startHTTPServer starts the HTTP server goroutine and returns the server.
// done is called once the Serve goroutine exits; pass nil to omit.
func startHTTPServer(rt *runtime.Runtime, state *listenerState, done func()) (*http.Server, error) {
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				http.Error(w, fmt.Sprintf("%v", rec), http.StatusInternalServerError)
			}
		}()
		dispatchRequest(rt, state, w, r)
	})

	addr := fmt.Sprintf("%s:%d", state.host, state.port)
	protocols := new(http.Protocols)
	protocols.SetHTTP1(true)
	protocols.SetHTTP2(true)
	if state.tlsCfg == nil {
		protocols.SetUnencryptedHTTP2(true)
	}

	timeout := state.timeout
	if timeout == 0 {
		timeout = 60 * time.Second
	}
	server := &http.Server{
		Addr:         addr,
		Handler:      mux,
		Protocols:    protocols,
		ReadTimeout:  timeout,
		WriteTimeout: timeout,
	}

	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return nil, err
	}
	var serveLn net.Listener = ln
	if state.tlsCfg != nil {
		serveLn = tls.NewListener(ln, state.tlsCfg)
	}
	go func() {
		_ = server.Serve(serveLn)
		if done != nil {
			done()
		}
	}()
	return server, nil
}

// dispatchRequest routes an incoming HTTP request to the matching service and resource method.
func dispatchRequest(rt *runtime.Runtime, state *listenerState, w http.ResponseWriter, r *http.Request) {
	state.mu.RLock()
	var found *serviceEntry
	var subPath string
	for _, e := range state.services {
		if strings.HasPrefix(r.URL.Path, e.basePath) {
			found = e
			subPath = r.URL.Path[len(e.basePath):]
			break
		}
	}
	state.mu.RUnlock()

	if found == nil {
		writeErrorJSON(w, r, http.StatusNotFound, "no matching resource found for path")
		return
	}

	segments := splitURLPath(subPath)
	ctx := rt.NewExternContext()

	httpMethod := strings.ToLower(r.Method)
	for _, accessorKey := range []string{httpMethod, "default"} {
		candidates, ok := found.svcObj.ResourceEntries(accessorKey)
		if !ok {
			continue
		}
		for i := range candidates {
			coerced, ok := coercePathForCandidate(ctx.TypeCtx, &candidates[i], segments)
			if !ok {
				continue
			}
			handle, ok := ctx.LookupResourceMethod(found.svcObj, accessorKey, coerced)
			if !ok {
				continue
			}
			// Count non-literal path params to determine how many user args the method expects.
			nonLiteralCount := 0
			for _, seg := range candidates[i].PathSegments {
				if _, isLit := values.LiteralPathSegment(seg); !isLit {
					nonLiteralCount++
				}
			}
			totalParams := runtime.GetBIRFunctionParamCount(ctx, candidates[i].FunctionLookupKey)
			extraArgCount := 0
			if totalParams >= 0 {
				extraArgCount = totalParams - nonLiteralCount
			}

			body, _ := readRequestBody(r)
			var invocationArgs []values.BalValue
			if extraArgCount > 0 {
				reqObj := buildRequest(ctx.TypeCtx, r.Method, r.URL.Path, r.Proto, r.Header, body, r.URL.RawQuery)
				invocationArgs = []values.BalValue{reqObj}
			}
			result, err := ctx.InvokeMethod(handle, invocationArgs)
			if err != nil {
				writeErrorJSON(w, r, http.StatusInternalServerError, err.Error())
				return
			}
			writeResult(ctx.TypeCtx, w, r, result)
			return
		}
	}
	// Path matched a service but no accessor+path combination worked. Check whether the
	// path would have matched under a different HTTP method and return 405 if so.
	for _, accessor := range found.svcObj.AllResourceMethodNames() {
		if accessor == httpMethod || accessor == "default" {
			continue
		}
		candidates, _ := found.svcObj.ResourceEntries(accessor)
		for i := range candidates {
			if _, ok := coercePathForCandidate(ctx.TypeCtx, &candidates[i], segments); ok {
				writeErrorJSON(w, r, http.StatusMethodNotAllowed, "method not allowed for path")
				return
			}
		}
	}
	writeErrorJSON(w, r, http.StatusNotFound, "no matching resource found for path")
}

// splitURLPath splits a URL sub-path into segments, stripping leading/trailing slashes.
func splitURLPath(p string) []string {
	p = strings.Trim(p, "/")
	if p == "" {
		return nil
	}
	return strings.Split(p, "/")
}

// coercePathForCandidate tries to coerce URL string segments to the typed values expected
// by the candidate resource entry. Returns (nil, false) if the segments don't match.
func coercePathForCandidate(tc semtypes.Context, entry *values.ResourceEntry, segments []string) ([]values.BalValue, bool) {
	required := len(entry.PathSegments)
	hasRest := !semtypes.IsNever(entry.RestSegmentTy)
	if len(segments) < required {
		return nil, false
	}
	if len(segments) > required && !hasRest {
		return nil, false
	}

	result := make([]values.BalValue, len(segments))
	for i := range required {
		seg := entry.PathSegments[i]
		v, ok := coerceSegment(tc, seg.Ty, segments[i])
		if !ok {
			return nil, false
		}
		result[i] = v
	}
	for i := required; i < len(segments); i++ {
		v, ok := coerceSegment(tc, entry.RestSegmentTy, segments[i])
		if !ok {
			return nil, false
		}
		result[i] = v
	}
	return result, true
}

// decodeBalIdentifier converts a Ballerina identifier token text to its URL-path form:
// strips a leading quoted-identifier prefix (') and replaces backslash escapes (\X → X).
func decodeBalIdentifier(s string) string {
	if len(s) == 0 {
		return s
	}
	if s[0] == '\'' {
		s = s[1:]
	}
	if !strings.ContainsRune(s, '\\') {
		return s
	}
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] == '\\' && i+1 < len(s) {
			i++
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

// coerceSegment coerces a URL path segment string to a typed value matching segTy.
func coerceSegment(tc semtypes.Context, segTy semtypes.SemType, s string) (values.BalValue, bool) {
	// Literal segment: must equal the expected string constant, after decoding any
	// Ballerina quoted-identifier prefix or backslash escapes from the stored literal.
	if shape := semtypes.SingleShape(segTy); shape.IsPresent() {
		if lit, ok := shape.Get().Value.(string); ok {
			if s != decodeBalIdentifier(lit) {
				return nil, false
			}
			// Return the raw stored literal so that its singleton type matches the stored
			// entry type when LookupResourceMethod re-validates via resourcePathMatches.
			return lit, true
		}
	}
	// Parameter segment: coerce based on type.
	if semtypes.IsSubtype(tc, semtypes.INT, segTy) {
		n, err := strconv.ParseInt(s, 10, 64)
		if err != nil {
			return nil, false
		}
		return n, true
	}
	if semtypes.IsSubtype(tc, semtypes.FLOAT, segTy) {
		f, err := strconv.ParseFloat(s, 64)
		if err != nil {
			return nil, false
		}
		return f, true
	}
	if semtypes.IsSubtype(tc, semtypes.BOOLEAN, segTy) {
		switch s {
		case "true":
			return true, true
		case "false":
			return false, true
		}
		return nil, false
	}
	// STRING or any other type: accept as-is.
	return s, true
}

// readRequestBody reads the request body bytes.
func readRequestBody(r *http.Request) ([]byte, error) {
	if r.Body == nil {
		return nil, nil
	}
	defer r.Body.Close()
	buf := make([]byte, 0, 512)
	tmp := make([]byte, 512)
	for {
		n, err := r.Body.Read(tmp)
		if n > 0 {
			buf = append(buf, tmp[:n]...)
		}
		if err != nil {
			break
		}
	}
	return buf, nil
}

// buildRequest constructs a Ballerina Request object from HTTP request data.
func buildRequest(tc semtypes.Context, method, rawPath, httpVersion string, headers map[string][]string, body []byte, rawQuery string) *values.Object {
	headersMap := newMappingValue(tc)
	for k, vals := range headers {
		items := make([]values.BalValue, len(vals))
		for i, v := range vals {
			items[i] = v
		}
		headersMap.Put(tc, strings.ToLower(k), newListValue(tc, items))
	}
	return values.NewObject(
		semtypes.OBJECT,
		map[string]values.BalValue{
			"rawPath":     rawPath,
			"method":      method,
			"httpVersion": httpVersion,
			"$headers":    headersMap,
			"$body":       string(body),
			"$queryStr":   rawQuery,
		},
		map[string]string{
			"getTextPayload":     "ballerina/http:Request.getTextPayload",
			"getJsonPayload":     "ballerina/http:Request.getJsonPayload",
			"getBinaryPayload":   "ballerina/http:Request.getBinaryPayload",
			"getHeader":          "ballerina/http:Request.getHeader",
			"getHeaders":         "ballerina/http:Request.getHeaders",
			"hasHeader":          "ballerina/http:Request.hasHeader",
			"getQueryParams":     "ballerina/http:Request.getQueryParams",
			"getQueryParamValue": "ballerina/http:Request.getQueryParamValue",
		},
		nil,
	)
}

// writeErrorJSON writes a JSON error response in the standard Ballerina HTTP error format.
func writeErrorJSON(w http.ResponseWriter, r *http.Request, status int, message string) {
	type errorPayload struct {
		Timestamp string `json:"timestamp"`
		Status    int    `json:"status"`
		Reason    string `json:"reason"`
		Message   string `json:"message"`
		Path      string `json:"path"`
		Method    string `json:"method"`
	}
	payload := errorPayload{
		Timestamp: time.Now().UTC().Format("2006-01-02T15:04:05.000000") + "Z",
		Status:    status,
		Reason:    http.StatusText(status),
		Message:   message,
		Path:      r.URL.Path,
		Method:    r.Method,
	}
	body, _ := json.Marshal(payload)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_, _ = w.Write(body)
}

// writeResult writes a Ballerina resource method return value as an HTTP response.
func writeResult(tc semtypes.Context, w http.ResponseWriter, r *http.Request, result values.BalValue) {
	switch v := result.(type) {
	case nil:
		w.WriteHeader(http.StatusAccepted)
	case *values.Error:
		writeErrorJSON(w, r, http.StatusInternalServerError, v.Message)
	case *values.Object:
		statusCodeVal, _ := v.Get("statusCode")
		statusCode := http.StatusOK
		if sc, ok := statusCodeVal.(int64); ok {
			statusCode = int(sc)
		}
		bodyVal, _ := v.Get("body")
		body, _ := bodyVal.(string)
		contentTypeVal, _ := v.Get("$contentType")
		contentType, _ := contentTypeVal.(string)

		// Emit headers from the response object.
		if hdrsVal, ok := v.Get("$headers"); ok {
			if hdrs, ok := hdrsVal.(*values.Map); ok {
				for _, k := range hdrs.Keys() {
					val, _ := hdrs.Get(k)
					list, ok := val.(*values.List)
					if !ok {
						continue
					}
					for i := range list.Len() {
						s, _ := list.Get(i).(string)
						if i == 0 {
							w.Header().Set(k, s)
						} else {
							w.Header().Add(k, s)
						}
					}
				}
			}
		}
		if contentType != "" {
			w.Header().Set("Content-Type", contentType)
		}
		w.WriteHeader(statusCode)
		if body != "" {
			_, _ = w.Write([]byte(body))
		}
	default:
		writeErrorJSON(w, r, http.StatusInternalServerError, "unexpected return type from resource method")
	}
}

// goToBalValue converts a Go value (from json.Decoder with UseNumber) to a Ballerina BalValue.
// JSON null → nil, bool → bool, json.Number → int64 or float64, string → string,
// []interface{} → *values.List with json[] type, map[string]interface{} → *values.Map with map<json> type.
// jsonListTy and jsonMapTy must be the structural json[] and map<json> semtypes so that
// `value is json` type checks return true for the produced values.
func goToBalValue(tc semtypes.Context, v interface{}, jsonListTy, jsonMapTy semtypes.SemType) values.BalValue {
	switch v := v.(type) {
	case nil:
		return nil
	case bool:
		return v
	case json.Number:
		if i, err := v.Int64(); err == nil {
			return i
		}
		f, _ := v.Float64()
		return f
	case string:
		return v
	case []interface{}:
		items := make([]values.BalValue, len(v))
		for i, elem := range v {
			items[i] = goToBalValue(tc, elem, jsonListTy, jsonMapTy)
		}
		return newTypedListValue(tc, jsonListTy, items)
	case map[string]interface{}:
		m := values.NewMap(jsonMapTy, semtypes.ToMappingAtomicType(tc, jsonMapTy), false, nil)
		for k, val := range v {
			m.Put(tc, k, goToBalValue(tc, val, jsonListTy, jsonMapTy))
		}
		return m
	default:
		return nil
	}
}
