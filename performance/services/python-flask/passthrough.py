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

"""Flask passthrough service forwarding POST bodies to the Netty echo backend
on port 8688. Served by gunicorn as `passthrough:app` (see run.sh)."""

import requests
from flask import Flask, Response, request

app = Flask(__name__)

BACKEND = "http://localhost:8688/"

# Shared networking baseline (see performance/README.md): connection reuse, pool
# sized to 512 (above the suite's 500-user peak so connections are reused, not
# evicted).
_session = requests.Session()
_session.mount(
    "http://",
    requests.adapters.HTTPAdapter(pool_connections=512, pool_maxsize=512),
)


@app.post("/passthrough")
def passthrough():
    content_type = request.headers.get("Content-Type", "text/plain")
    try:
        resp = _session.post(
            BACKEND,
            data=request.get_data(),
            headers={"Content-Type": content_type},
            timeout=300,
        )
    except requests.RequestException as err:
        return Response(str(err), status=502, mimetype="text/plain")

    return Response(
        resp.content,
        status=resp.status_code,
        mimetype=resp.headers.get("Content-Type", "text/plain"),
    )


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=9090, threaded=True)
