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

"""Plain-stdlib hello-world HTTP service on port 9090 (ThreadingHTTPServer)."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

BODY = b"Hello, World!"


class HelloHandler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"  # enable keep-alive

    def do_GET(self):
        if self.path == "/hello":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(BODY)))
            self.end_headers()
            self.wfile.write(BODY)
        else:
            self.send_response(404)
            self.send_header("Content-Length", "0")
            self.end_headers()

    def log_message(self, *args):  # silence per-request logging
        pass


def main():
    server = ThreadingHTTPServer(("", 9090), HelloHandler)
    print("Hello service listening on :9090 (HTTP/1.1)")
    server.serve_forever()


if __name__ == "__main__":
    main()
