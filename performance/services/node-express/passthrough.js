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
const http = require('http');

const agent = new http.Agent({
  keepAlive: true,
  maxSockets: 0,
  maxFreeSockets: 256,
  timeout: 300000,
});

const app = express();

// No body parser: stream the raw request body straight to the backend.
app.post('/passthrough', (req, res) => {
  const headers = Object.assign({}, req.headers);
  delete headers.connection;
  delete headers['keep-alive'];
  delete headers.host;

  const proxyReq = http.request(
    { host: 'localhost', port: 8688, path: '/', method: 'POST', headers, agent },
    (proxyRes) => {
      res.writeHead(proxyRes.statusCode, proxyRes.headers);
      proxyRes.pipe(res);
    }
  );

  proxyReq.on('error', (err) => {
    res.status(502).type('text/plain').send(err.message);
  });

  req.pipe(proxyReq);
});

const server = app.listen(9090, () =>
  console.log('Passthrough service (express) listening on :9090 (HTTP/1.1)')
);
server.keepAliveTimeout = 300000;
