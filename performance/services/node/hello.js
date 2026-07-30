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

const http = require('http');
const cluster = require('cluster');
const os = require('os');

// Node's event loop is single-threaded, so scale across cores with the cluster
// module — one worker per core, all sharing the :9090 listen socket. This is
// the production-standard way to use every core, matching the multi-core parity
// of the other runtimes (see performance/README.md).
const WORKERS = os.availableParallelism ? os.availableParallelism() : os.cpus().length;

function serve() {
  const BODY = Buffer.from('Hello, World!');

  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/hello') {
      res.writeHead(200, { 'Content-Type': 'text/plain', 'Content-Length': BODY.length });
      res.end(BODY);
      return;
    }
    res.writeHead(404);
    res.end();
  });

  server.keepAliveTimeout = 300000;
  server.listen(9090);
}

if (cluster.isPrimary && WORKERS > 1) {
  for (let i = 0; i < WORKERS; i++) cluster.fork();
  console.log(`Hello service listening on :9090 (HTTP/1.1), ${WORKERS} workers`);
} else {
  serve();
  if (WORKERS <= 1) console.log('Hello service listening on :9090 (HTTP/1.1)');
}
