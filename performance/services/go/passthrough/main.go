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
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"time"
)

const backendURL = "http://localhost:8688"

func newProxy() *httputil.ReverseProxy {
	backend, err := url.Parse(backendURL)
	if err != nil {
		log.Fatalf("parse backend URL: %v", err)
	}

	// Shared networking baseline (see performance/README.md): keep-alive pool
	// sized to 512 (above the suite's 500-user peak so connections are reused,
	// not evicted), 300s idle timeout, 15s connect timeout, OS TCP keep-alive
	// off (matches jBallerina's socketConfig.keepAlive=false), no request
	// decompression (don't inject Accept-Encoding: gzip; Netty echoes it back).
	transport := &http.Transport{
		DialContext: (&net.Dialer{
			Timeout:   15 * time.Second,
			KeepAlive: -1,
		}).DialContext,
		MaxIdleConns:        512,
		MaxIdleConnsPerHost: 512,
		IdleConnTimeout:     300 * time.Second,
		DisableCompression:  true,
		WriteBufferSize:     32 * 1024,
		ReadBufferSize:      32 * 1024,
	}

	// httputil.ReverseProxy is Go's idiomatic reverse proxy: it streams the
	// request and response bodies, strips hop-by-hop headers per RFC 7230, and
	// reuses pooled keep-alive connections through the transport above.
	return &httputil.ReverseProxy{
		Transport: transport,
		Rewrite: func(r *httputil.ProxyRequest) {
			r.SetURL(backend)
			r.Out.URL.Path = "/"
			r.Out.Host = backend.Host
		},
		ErrorHandler: func(w http.ResponseWriter, _ *http.Request, err error) {
			log.Printf("Error at h1_h1_passthrough: %v", err)
			http.Error(w, err.Error(), http.StatusBadGateway)
		},
	}
}

func main() {
	mux := http.NewServeMux()
	mux.Handle("POST /passthrough", newProxy())

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
