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
import io.netty.handler.codec.http.DefaultFullHttpResponse;
import io.netty.handler.codec.http.FullHttpResponse;
import io.netty.handler.codec.http.HttpHeaderNames;
import io.netty.handler.codec.http.HttpHeaderValues;
import io.netty.handler.codec.http.HttpResponseStatus;
import io.netty.handler.codec.http.HttpVersion;

/**
 * Persistent handler on each pooled backend channel. It correlates a backend
 * response with the inbound request stored in {@link BackendPool#PENDING},
 * writes the response back to the original client, and returns the channel to
 * the pool.
 */
public class BackendResponseHandler extends SimpleChannelInboundHandler<FullHttpResponse> {

    private final BackendPool pool;

    public BackendResponseHandler(BackendPool pool) {
        this.pool = pool;
    }

    @Override
    protected void channelRead0(ChannelHandlerContext backendCtx, FullHttpResponse resp) {
        Channel backend = backendCtx.channel();
        BackendPool.Pending pending = backend.attr(BackendPool.PENDING).getAndSet(null);

        // Copy the response before the pool reuses the channel (and before
        // SimpleChannelInboundHandler auto-releases the inbound buffer).
        FullHttpResponse copy = new DefaultFullHttpResponse(
                HttpVersion.HTTP_1_1, resp.status(), resp.content().retainedDuplicate());
        copy.headers().set(resp.headers());
        copy.headers().remove(HttpHeaderNames.CONNECTION);
        copy.headers().setInt(HttpHeaderNames.CONTENT_LENGTH, copy.content().readableBytes());

        pool.release(backend);

        if (pending == null) {
            copy.release();
            return;
        }

        if (pending.keepAlive) {
            copy.headers().set(HttpHeaderNames.CONNECTION, HttpHeaderValues.KEEP_ALIVE);
            pending.inboundCtx.writeAndFlush(copy);
        } else {
            pending.inboundCtx.writeAndFlush(copy).addListener(ChannelFutureListener.CLOSE);
        }
    }

    @Override
    public void exceptionCaught(ChannelHandlerContext backendCtx, Throwable cause) {
        Channel backend = backendCtx.channel();
        BackendPool.Pending pending = backend.attr(BackendPool.PENDING).getAndSet(null);
        if (pending != null) {
            FullHttpResponse err = new DefaultFullHttpResponse(
                    HttpVersion.HTTP_1_1, HttpResponseStatus.BAD_GATEWAY);
            err.headers().setInt(HttpHeaderNames.CONTENT_LENGTH, 0);
            pending.inboundCtx.writeAndFlush(err).addListener(ChannelFutureListener.CLOSE);
        }
        backendCtx.close();
    }
}
