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

const express = require('express');
const cluster = require('cluster');
const os = require('os');

// One worker per core via the cluster module (see performance/README.md), all
// sharing the :9090 listen socket — the production-standard way to use every
// core, matching the multi-core parity of the other runtimes.
const WORKERS = os.availableParallelism ? os.availableParallelism() : os.cpus().length;

function serve() {
  const app = express();
  const BODY = 'Hello, World!';

  app.get('/hello', (req, res) => {
    res.type('text/plain').send(BODY);
  });

  const server = app.listen(9090);
  server.keepAliveTimeout = 300000;
}

if (cluster.isPrimary && WORKERS > 1) {
  for (let i = 0; i < WORKERS; i++) cluster.fork();
  console.log(`Hello service (express) listening on :9090 (HTTP/1.1), ${WORKERS} workers`);
} else {
  serve();
  if (WORKERS <= 1) console.log('Hello service (express) listening on :9090 (HTTP/1.1)');
}
