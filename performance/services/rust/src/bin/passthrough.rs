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

//! Axum passthrough service forwarding POST bodies to the Netty echo backend
//! on port 8688 via a pooled reqwest client.

use std::time::Duration;

use axum::body::Bytes;
use axum::extract::State;
use axum::http::{HeaderMap, StatusCode};
use axum::response::{IntoResponse, Response};
use axum::routing::post;
use axum::Router;

const BACKEND: &str = "http://localhost:8688/";

#[tokio::main]
async fn main() {
    // Shared networking baseline (see performance/README.md): connection reuse,
    // unlimited active connections, idle pool sized to 512 (above the suite's
    // 500-user peak so connections are reused, not evicted), 300s idle timeout,
    // 15s connect timeout, TCP_NODELAY on, no decompression (no compression
    // features are enabled on reqwest).
    let client = reqwest::Client::builder()
        .pool_max_idle_per_host(512)
        .pool_idle_timeout(Duration::from_secs(300))
        .connect_timeout(Duration::from_secs(15))
        .tcp_nodelay(true)
        .build()
        .expect("build reqwest client");

    let app = Router::new()
        .route("/passthrough", post(passthrough))
        .with_state(client);
    let listener = tokio::net::TcpListener::bind("0.0.0.0:9090")
        .await
        .expect("bind :9090");
    println!("Passthrough service (axum) listening on :9090 (HTTP/1.1)");
    axum::serve(listener, app).await.expect("serve");
}

async fn passthrough(
    State(client): State<reqwest::Client>,
    headers: HeaderMap,
    body: Bytes,
) -> Response {
    let content_type = headers
        .get("content-type")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("text/plain")
        .to_owned();

    let result = client
        .post(BACKEND)
        .header("Content-Type", content_type)
        .body(body)
        .send()
        .await;

    let resp = match result {
        Ok(resp) => resp,
        Err(err) => return (StatusCode::BAD_GATEWAY, err.to_string()).into_response(),
    };

    let status = resp.status();
    let backend_ct = resp
        .headers()
        .get("content-type")
        .and_then(|v| v.to_str().ok())
        .unwrap_or("text/plain")
        .to_owned();
    match resp.bytes().await {
        Ok(data) => (status, [("Content-Type", backend_ct)], data).into_response(),
        Err(err) => (StatusCode::BAD_GATEWAY, err.to_string()).into_response(),
    }
}
