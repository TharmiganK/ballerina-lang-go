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

package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"net/url"
	"sync"
	"time"
)

var (
	backendHost = "localhost:8688"

	// Pre-parsed backend URL; copied by value per-request — eliminates url.Parse
	// allocation (~4 string allocs) on every incoming request.
	backendBaseURL = url.URL{Scheme: "http", Host: backendHost, Path: "/"}

	backendClient = &http.Client{
		Transport: &http.Transport{
			DialContext: (&net.Dialer{
				Timeout: 15 * time.Second,
				// Disable TCP keep-alive to match jBallerina's socketConfig.keepAlive=false.
				// Active keepalive probes can desync Netty's connection state machine under load.
				KeepAlive: -1,
			}).DialContext,
			DisableKeepAlives:  false,
			DisableCompression: true, // don't inject Accept-Encoding: gzip; Netty echoes it back

			// Pool sized to match jBallerina defaults (maxIdleConnections=100, unlimited active).
			// Go's default MaxIdleConnsPerHost=2 causes pool exhaustion under concurrent load.
			MaxIdleConns:        512,
			MaxIdleConnsPerHost: 100,
			MaxConnsPerHost:     0,

			// 300s matches jBallerina's minEvictableIdleTime so the pool never holds a
			// connection the backend has already closed → eliminates "connection reset" errors.
			IdleConnTimeout: 300 * time.Second,
			// ResponseHeaderTimeout disabled: a hard deadline here fires under backend load
			// and turns latency spikes into 502 errors. Let the upstream client's own timeout
			// govern end-to-end deadline instead.

			// 32KB buffers fit a full 10KB payload in a single bufio flush/read,
			// cutting write+read syscalls per request from ~6 (default 4KB) to ~2.
			WriteBufferSize: 32 * 1024,
			ReadBufferSize:  32 * 1024,
		},
	}

	// Hop-by-hop headers per RFC 7230 §6.1 + RFC 2616 §13.5.1.
	// Must NOT be forwarded by a proxy; forwarding Connection/Keep-Alive verbatim
	// causes Netty's keep-alive state machine to desync under load → connection resets.
	hopHeaders = [...]string{
		"Connection",
		"Keep-Alive",
		"Proxy-Authenticate",
		"Proxy-Authorization",
		"Proxy-Connection",
		"Te",
		"Trailer",
		"Transfer-Encoding",
		"Upgrade",
	}

	// headerPool avoids make(http.Header) on every request (~18K allocs/sec at peak).
	// The map is cleared on Get and returned on Put; slice values point into r.Header
	// strings which are valid for the handler's lifetime.
	headerPool = sync.Pool{
		New: func() any { return make(http.Header, 8) },
	}
)

// removeHopByHop removes hop-by-hop headers from h in place.
// It also honors the Connection header's own list per RFC 7230 §6.1.
func removeHopByHop(h http.Header) {
	for _, f := range h["Connection"] {
		h.Del(f)
	}
	for _, k := range hopHeaders {
		h.Del(k)
	}
}

func passthroughHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	// Value copy of the pre-parsed URL — no url.Parse, no heap allocation for
	// the url.URL struct itself (string fields are shared/interned).
	u := backendBaseURL

	// Acquire a pooled header map; clear it for reuse.
	outHeader := headerPool.Get().(http.Header)
	for k := range outHeader {
		delete(outHeader, k)
	}

	// Direct map assignment bypasses textproto.CanonicalMIMEHeaderKey per key.
	// Safe because Go's http.Server delivers headers in canonical form already.
	for k, vv := range r.Header {
		outHeader[k] = vv
	}
	removeHopByHop(outHeader)

	// Construct the request manually to avoid NewRequestWithContext's url.Parse
	// and make(Header) allocations.
	req := &http.Request{
		Method:        http.MethodPost,
		URL:           &u,
		Header:        outHeader,
		Body:          r.Body,
		ContentLength: r.ContentLength,
		Host:          backendHost,
		Proto:         "HTTP/1.1",
		ProtoMajor:    1,
		ProtoMinor:    1,
	}
	// Decouple from the client connection's context: the backend request must not
	// be cancelled when the upstream client disconnects or wrk resets the connection.
	req = req.WithContext(context.Background())

	resp, err := backendClient.Do(req)
	// Transport has finished reading req.Header inside Do(); safe to return the map.
	headerPool.Put(outHeader)
	if err != nil {
		log.Printf("Error at h1_h1_passthrough: %v", err)
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	// Direct map copy for response headers (same canonicalization argument as above).
	respHeader := w.Header()
	for k, vv := range resp.Header {
		respHeader[k] = vv
	}
	removeHopByHop(respHeader)

	w.WriteHeader(resp.StatusCode)

	// io.Copy(w, resp.Body) resolves to w.ReadFrom(resp.Body) via the http.ResponseWriter
	// interface. The server's ReadFrom uses getCopyBuf() — a package-level sync.Pool of
	// 32KB arrays — so no user-level copy-buffer pool is needed here.
	if _, err := io.Copy(w, resp.Body); err != nil {
		log.Printf("Error at h1_h1_passthrough (copy): %v", err)
	}
}

func main() {
	mux := http.NewServeMux()
	mux.HandleFunc("/passthrough", passthroughHandler)

	server := &http.Server{
		Addr:    ":9090",
		Handler: mux,

		// ReadHeaderTimeout guards against slow-loris attacks / stalled clients.
		// No ReadTimeout/WriteTimeout — they would abort passthrough bodies mid-stream.
		ReadHeaderTimeout: 5 * time.Second,
		IdleTimeout:       300 * time.Second, // match backend's minEvictableIdleTime
		MaxHeaderBytes:    1 << 14,           // 16KB; default 1MB is wasteful
	}

	fmt.Println("Passthrough service listening on :9090 (HTTP/1.1)")
	if err := server.ListenAndServe(); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}
