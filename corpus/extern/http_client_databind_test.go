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
	"bufio"
	"fmt"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
)

// databindServer serves one canned response per path, each with a Content-Type that selects
// a particular payload builder.
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
		// A status error whose declared JSON body does not parse.
		"/missing-broken-json": {404, "application/json", `{"error": nope}`},
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

// TestHttpClientDataBindLocal covers each payload builder and the unknown-media-type
// fallback, including targets narrower than the type their builder produces.
func TestHttpClientDataBindLocal(t *testing.T) {
	server := databindServer()
	defer server.Close()
	runExtern(t, fileCase("http-client-databind-local-v"), newHTTPPal(rewriteClient(server.URL)), nil)
}

// TestHttpClientDataBindErrorsLocal covers the failure paths: status mapping, binding
// mismatches, incompatible media types, and the empty-body rules.
func TestHttpClientDataBindErrorsLocal(t *testing.T) {
	server := databindServer()
	defer server.Close()
	runExtern(t, fileCase("http-client-databind-errors-local-v"), newHTTPPal(rewriteClient(server.URL)), nil)
}

// truncatingServer promises a Content-Length it never delivers, then resets the connection,
// so reading the response body fails.
func truncatingServer(t *testing.T) *httptest.Server {
	t.Helper()
	contentTypes := map[string]string{
		"/trunc-json": "application/json",
		"/trunc-text": "text/plain",
		"/trunc-blob": "application/octet-stream",
		"/trunc-form": "application/x-www-form-urlencoded",
		"/trunc-404":  "application/json",
	}
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, _, err := w.(http.Hijacker).Hijack()
		if err != nil {
			t.Error(err)
			return
		}
		status := "200 OK"
		if r.URL.Path == "/trunc-404" {
			status = "404 Not Found"
		}
		bw := bufio.NewWriter(conn)
		_, _ = fmt.Fprintf(bw, "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: 100\r\n\r\n",
			status, contentTypes[r.URL.Path])
		_, _ = bw.WriteString("short")
		_ = bw.Flush()
		_ = conn.(*net.TCPConn).SetLinger(0)
		_ = conn.Close()
	}))
}

// TestHttpClientDataBindReadFailureLocal covers the read-failure path through each builder,
// a narrow target (where the failure must survive the conversion step), and a status error.
func TestHttpClientDataBindReadFailureLocal(t *testing.T) {
	server := truncatingServer(t)
	defer server.Close()
	runExtern(t, fileCase("http-client-databind-read-failure-local-v"), newHTTPPal(rewriteClient(server.URL)), nil)
}
