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

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.pool.ChannelPoolHandler;
import io.netty.channel.pool.SimpleChannelPool;
import io.netty.channel.socket.nio.NioSocketChannel;
import io.netty.handler.codec.http.HttpClientCodec;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.util.AttributeKey;
import io.netty.util.concurrent.Future;

/**
 * Pool of keep-alive channels to the backend. Each pooled channel carries an
 * HTTP client pipeline plus a persistent {@link BackendResponseHandler}. The
 * inbound request awaiting a given backend channel's response is stored in the
 * {@link #PENDING} attribute so the response handler can dispatch it back
 * without per-request pipeline mutation.
 */
public class BackendPool {

    /** Inbound request context awaiting this backend channel's response. */
    static final AttributeKey<Pending> PENDING = AttributeKey.valueOf("perf.pending");

    private final SimpleChannelPool pool;

    public BackendPool(EventLoopGroup group, String host, int port) {
        // Shared networking baseline (see performance/README.md): connection
        // reuse via the pool (unlimited active), TCP_NODELAY on, OS-level TCP
        // keep-alive off (matches Go/jBallerina clients), 15s connect timeout.
        // SimpleChannelPool keeps all released connections for reuse.
        Bootstrap bootstrap = new Bootstrap()
                .group(group)
                .channel(NioSocketChannel.class)
                .option(ChannelOption.SO_KEEPALIVE, false)
                .option(ChannelOption.TCP_NODELAY, true)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 15000)
                .remoteAddress(host, port);
        this.pool = new SimpleChannelPool(bootstrap, new BackendChannelPoolHandler(this));
    }

    public Future<Channel> acquire() {
        return pool.acquire();
    }

    public void release(Channel channel) {
        pool.release(channel);
    }

    /** Pending inbound request state carried on a backend channel. */
    static final class Pending {
        final ChannelHandlerContext inboundCtx;
        final boolean keepAlive;

        Pending(ChannelHandlerContext inboundCtx, boolean keepAlive) {
            this.inboundCtx = inboundCtx;
            this.keepAlive = keepAlive;
        }
    }

    private static final class BackendChannelPoolHandler implements ChannelPoolHandler {

        private final BackendPool owner;

        BackendChannelPoolHandler(BackendPool owner) {
            this.owner = owner;
        }

        @Override
        public void channelCreated(Channel ch) {
            ch.pipeline().addLast(new HttpClientCodec());
            ch.pipeline().addLast(new HttpObjectAggregator(2 * 1024 * 1024));
            ch.pipeline().addLast(new BackendResponseHandler(owner));
        }

        @Override
        public void channelAcquired(Channel ch) {
            // no-op
        }

        @Override
        public void channelReleased(Channel ch) {
            // no-op
        }
    }
}
