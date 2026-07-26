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

"""FastAPI passthrough service forwarding POST bodies to the Netty echo backend
on port 8688 via an aiohttp client. Served by uvicorn as `passthrough:app` with
uvloop + httptools and one worker per core (see run.sh)."""

# Defer annotation evaluation so the `X | None` union syntax (PEP 604) works on
# Python 3.9, which is still shipped on some hosts (e.g. Amazon Linux 2023).
from __future__ import annotations

from contextlib import asynccontextmanager

import aiohttp
from fastapi import FastAPI, Request, Response

BACKEND = "http://localhost:8688/"

# Shared networking baseline (see performance/README.md): connection reuse,
# unlimited active connections, 300s idle timeout, 15s connect timeout,
# TCP_NODELAY on (aiohttp default). aiohttp has no fixed idle-connection cap
# (like Netty's pool, it reuses all released connections), and each uvicorn
# worker process holds its own pool.
_session: aiohttp.ClientSession | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    global _session
    _session = aiohttp.ClientSession(
        connector=aiohttp.TCPConnector(limit=0, keepalive_timeout=300),
        timeout=aiohttp.ClientTimeout(connect=15, sock_read=300),
        auto_decompress=False,
    )
    yield
    await _session.close()


app = FastAPI(lifespan=lifespan)


@app.post("/passthrough")
async def passthrough(request: Request):
    content_type = request.headers.get("Content-Type", "text/plain")
    body = await request.body()
    try:
        async with _session.post(
            BACKEND, data=body, headers={"Content-Type": content_type}
        ) as resp:
            data = await resp.read()
            return Response(
                content=data,
                status_code=resp.status,
                media_type=resp.headers.get("Content-Type", "text/plain"),
            )
    except aiohttp.ClientError as err:
        return Response(content=str(err), status_code=502, media_type="text/plain")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=9090)
