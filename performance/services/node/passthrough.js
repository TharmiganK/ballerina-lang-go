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

// Keep-alive agent pooled to the backend. Shared networking baseline (see
// performance/README.md): unlimited active connections, idle pool sized to 512
// (above the suite's 500-user peak so connections are reused, not evicted),
// 300s idle timeout.
const agent = new http.Agent({
  keepAlive: true,
  maxSockets: 0,          // unlimited active connections
  maxFreeSockets: 512,    // max idle connections per host
  timeout: 300000,        // 300s idle socket timeout
});

const BACKEND = { host: 'localhost', port: 8688, path: '/', agent };

const server = http.createServer((req, res) => {
  if (req.method !== 'POST' || req.url !== '/passthrough') {
    res.writeHead(404);
    res.end();
    return;
  }

  const headers = Object.assign({}, req.headers);
  delete headers.connection;
  delete headers['keep-alive'];
  delete headers.host;

  const proxyReq = http.request(
    { host: BACKEND.host, port: BACKEND.port, path: BACKEND.path, method: 'POST', headers, agent },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on('error', (err) => {
    res.writeHead(502, { 'Content-Type': 'text/plain' });
    res.end(err.message);
  });

  req.pipe(proxyReq);
});

server.keepAliveTimeout = 300000;
server.listen(9090, () => console.log('Passthrough service listening on :9090 (HTTP/1.1)'));
