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

import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.handler.codec.http.HttpServerCodec;

/**
 * Entry point for the Netty gateway. Serves one of two scenarios on the given
 * port: a static hello-world response, or a passthrough that forwards POST
 * bodies to the Netty echo backend.
 */
public final class Main {

    private String scenario = "hello";
    private int port = 9090;
    private String backendHost = "localhost";
    private int backendPort = 8688;

    // Plain arg parsing (no reflection) so the GraalVM native image needs no
    // extra reflection metadata.
    public static void main(String[] args) throws Exception {
        Main main = new Main();
        for (int i = 0; i + 1 < args.length; i += 2) {
            switch (args[i]) {
                case "--scenario" -> main.scenario = args[i + 1];
                case "--port" -> main.port = Integer.parseInt(args[i + 1]);
                case "--backend-host" -> main.backendHost = args[i + 1];
                case "--backend-port" -> main.backendPort = Integer.parseInt(args[i + 1]);
                default -> throw new IllegalArgumentException("Unknown option: " + args[i]);
            }
        }
        main.run();
    }

    private void run() throws Exception {
        boolean passthrough = "passthrough".equals(scenario);
        EventLoopGroup boss = new NioEventLoopGroup(1);
        EventLoopGroup worker = new NioEventLoopGroup();
        final BackendPool pool = passthrough
                ? new BackendPool(worker, backendHost, backendPort)
                : null;
        try {
            ServerBootstrap bootstrap = new ServerBootstrap();
            bootstrap.group(boss, worker)
                    .channel(NioServerSocketChannel.class)
                    .option(ChannelOption.SO_BACKLOG, 1024)
                    .childOption(ChannelOption.SO_KEEPALIVE, true)
                    .childHandler(new ChannelInitializer<SocketChannel>() {
                        @Override
                        protected void initChannel(SocketChannel ch) {
                            ch.pipeline().addLast(new HttpServerCodec());
                            ch.pipeline().addLast(new HttpObjectAggregator(2 * 1024 * 1024));
                            if (passthrough) {
                                ch.pipeline().addLast(new PassthroughHandler(pool, backendHost, backendPort));
                            } else {
                                ch.pipeline().addLast(new HelloHandler());
                            }
                        }
                    });
            Channel channel = bootstrap.bind(port).sync().channel();
            System.out.println(scenario + " service (netty) listening on :" + port + " (HTTP/1.1)");
            channel.closeFuture().sync();
        } finally {
            boss.shutdownGracefully();
            worker.shutdownGracefully();
        }
    }
}
