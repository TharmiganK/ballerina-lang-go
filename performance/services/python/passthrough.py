# Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
#
# WSO2 LLC. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

"""Plain-stdlib passthrough service on port 9090 forwarding POST bodies to the
Netty echo backend on port 8688. Uses a per-thread keep-alive connection."""

import http.client
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BACKEND_HOST = "localhost"
BACKEND_PORT = 8688

_local = threading.local()


def _backend_conn():
    conn = getattr(_local, "conn", None)
    if conn is None:
        conn = http.client.HTTPConnection(BACKEND_HOST, BACKEND_PORT, timeout=300)
        _local.conn = conn
    return conn


class PassthroughHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"  # enable keep-alive

    def do_POST(self):
        if self.path != "/passthrough":
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(length) if length else b""

        headers = {"Content-Type": self.headers.get("Content-Type", "text/plain")}
        try:
            conn = _backend_conn()
            conn.request("POST", "/", body=body, headers=headers)
            resp = conn.getresponse()
            data = resp.read()
        except Exception as err:  # reset the pooled connection on failure
            _local.conn = None
            self.send_response(502)
            msg = str(err).encode()
            self.send_header("Content-Length", str(len(msg)))
            self.end_headers()
            self.wfile.write(msg)
            return

        self.send_response(resp.status)
        self.send_header("Content-Type", resp.getheader("Content-Type", "text/plain"))
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):  # silence per-request logging
        pass


def main():
    server = ThreadingHTTPServer(("", 9090), PassthroughHandler)
    print("Passthrough service listening on :9090 (HTTP/1.1)")
    server.serve_forever()


if __name__ == "__main__":
    main()
