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

// Bun-native hello-world service using Bun.serve. Each Bun process is
// single-threaded, so scale across cores by spawning one process per core, all
// binding the same port with reusePort:true (the kernel load-balances across
// them). Matches the multi-core parity of the other runtimes; see
// performance/README.md.

import { cpus } from 'os';

const WORKERS = cpus().length;

// The primary forks WORKERS-1 additional copies of itself; every process
// (primary included) then serves with reusePort. Children share the primary's
// process group, so the suite tears them all down with one group signal.
if (!process.env.BUN_WORKER && WORKERS > 1) {
  for (let i = 1; i < WORKERS; i++) {
    Bun.spawn(['bun', import.meta.path], {
      env: { ...process.env, BUN_WORKER: '1' },
      stdout: 'inherit',
      stderr: 'inherit',
    });
  }
}

Bun.serve({
  port: 9090,
  reusePort: true,
  fetch(req) {
    const url = new URL(req.url);
    if (url.pathname === '/hello') {
      return new Response('Hello, World!', {
        headers: { 'Content-Type': 'text/plain' },
      });
    }
    return new Response('', { status: 404 });
  },
});

if (!process.env.BUN_WORKER) {
  console.log(`Hello service (bun) listening on :9090 (HTTP/1.1), ${WORKERS} workers`);
}
