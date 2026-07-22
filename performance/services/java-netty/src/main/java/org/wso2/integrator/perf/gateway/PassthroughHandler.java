/*
 * Copyright (c) 2026 WSO2 LLC. (http://www.wso2.com).
 *
 * WSO2 LLC. licenses this file to you under the Apache License,
 * Version 2.0 (the "License"); you may not use this file except
 * in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */

package org.wso2.integrator.perf.gateway;

import io.netty.channel.Channel;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.SimpleChannelInboundHandler;
import io.netty.handler.codec.http.DefaultFullHttpRequest;
import io.netty.handler.codec.http.DefaultFullHttpResponse;
import io.netty.handler.codec.http.FullHttpRequest;
import io.netty.handler.codec.http.FullHttpResponse;
import io.netty.handler.codec.http.HttpHeaderNames;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpResponseStatus;
import io.netty.handler.codec.http.HttpUtil;
import io.netty.handler.codec.http.HttpVersion;
import io.netty.util.concurrent.Future;
import io.netty.util.concurrent.FutureListener;

/**
 * Forwards POST /passthrough bodies to the backend via a pooled keep-alive
 * channel. The backend response is delivered asynchronously by
 * {@link BackendResponseHandler}.
 */
public class PassthroughHandler extends SimpleChannelInboundHandler<FullHttpRequest> {

    private final BackendPool pool;
    private final String backendAuthority;

    public PassthroughHandler(BackendPool pool, String backendHost, int backendPort) {
        this.pool = pool;
        this.backendAuthority = backendHost + ":" + backendPort;
    }

    @Override
    protected void channelRead0(ChannelHandlerContext ctx, FullHttpRequest req) {
        final boolean keepAlive = HttpUtil.isKeepAlive(req);

        if (!HttpMethod.POST.equals(req.method()) || !"/passthrough".equals(req.uri())) {
            respond(ctx, HttpResponseStatus.NOT_FOUND, keepAlive);
            return;
        }

        // Extract everything needed synchronously; the inbound buffer is released
        // when channelRead0 returns, so retain the body for the async forward.
        final FullHttpRequest out = new DefaultFullHttpRequest(
                HttpVersion.HTTP_1_1, HttpMethod.POST, "/", req.content().retainedDuplicate());
        out.headers().set(req.headers());
        out.headers().set(HttpHeaderNames.HOST, backendAuthority);
        out.headers().remove(HttpHeaderNames.CONNECTION);
        out.headers().setInt(HttpHeaderNames.CONTENT_LENGTH, out.content().readableBytes());

        final ChannelHandlerContext inboundCtx = ctx;
        pool.acquire().addListener((FutureListener<Channel>) future -> {
            if (!future.isSuccess()) {
                out.release();
                respond(inboundCtx, HttpResponseStatus.BAD_GATEWAY, keepAlive);
                return;
            }
            Channel backend = future.getNow();
            backend.attr(BackendPool.PENDING).set(new BackendPool.Pending(inboundCtx, keepAlive));
            backend.writeAndFlush(out);
        });
    }

    private static void respond(ChannelHandlerContext ctx, HttpResponseStatus status, boolean keepAlive) {
        FullHttpResponse response = new DefaultFullHttpResponse(HttpVersion.HTTP_1_1, status);
        response.headers().setInt(HttpHeaderNames.CONTENT_LENGTH, 0);
        if (keepAlive) {
            ctx.writeAndFlush(response);
        } else {
            ctx.writeAndFlush(response).addListener(ChannelFutureListener.CLOSE);
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) {
        ctx.close();
    }
}
