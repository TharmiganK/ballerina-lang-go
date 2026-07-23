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

'use strict';

// Bun-native passthrough service forwarding POST bodies to the Netty echo
// backend on port 8688 via Bun's built-in fetch. Bun's fetch keeps upstream
// connections alive by default but exposes no pool-size knobs — see the
// deviations note in performance/README.md.

const BACKEND = 'http://localhost:8688/';

Bun.serve({
  port: 9090,
  async fetch(req) {
    const url = new URL(req.url);
    if (req.method !== 'POST' || url.pathname !== '/passthrough') {
      return new Response('', { status: 404 });
    }
    try {
      const resp = await fetch(BACKEND, {
        method: 'POST',
        headers: {
          'Content-Type': req.headers.get('content-type') ?? 'text/plain',
        },
        body: await req.arrayBuffer(),
      });
      return new Response(await resp.arrayBuffer(), {
        status: resp.status,
        headers: {
          'Content-Type': resp.headers.get('content-type') ?? 'text/plain',
        },
      });
    } catch (err) {
      return new Response(String(err), {
        status: 502,
        headers: { 'Content-Type': 'text/plain' },
      });
    }
  },
});

console.log('Passthrough service (bun) listening on :9090 (HTTP/1.1)');
