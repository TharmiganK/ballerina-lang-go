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

package org.wso2.integrator.perf.spring;

import io.netty.channel.ChannelOption;
import java.time.Duration;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.MediaType;
import org.springframework.http.client.reactive.ReactorClientHttpConnector;
import org.springframework.web.reactive.function.client.WebClient;
import org.springframework.web.reactive.function.server.RouterFunction;
import org.springframework.web.reactive.function.server.ServerResponse;
import reactor.netty.http.client.HttpClient;
import reactor.netty.resources.ConnectionProvider;

import static org.springframework.web.reactive.function.server.RequestPredicates.POST;
import static org.springframework.web.reactive.function.server.RouterFunctions.route;

/**
 * Passthrough scenario: {@code POST /passthrough} forwards the request body
 * to the Netty echo backend on port 8688 through a pooled WebClient.
 */
@Configuration
@ConditionalOnProperty(name = "scenario", havingValue = "passthrough")
public class PassthroughConfig {

    private static final String BACKEND = "http://localhost:8688/";

    // Shared networking baseline (see performance/README.md): connection
    // reuse, effectively unlimited active connections, 300s idle timeout,
    // 15s connect timeout, TCP_NODELAY on (Reactor Netty default). Like raw
    // Netty's pool, Reactor Netty has no separate idle-connection cap.
    @Bean
    public WebClient backendClient(WebClient.Builder builder) {
        ConnectionProvider provider = ConnectionProvider.builder("perf-backend")
                .maxConnections(10_000)
                .pendingAcquireMaxCount(-1)
                .maxIdleTime(Duration.ofSeconds(300))
                .build();
        HttpClient httpClient = HttpClient.create(provider)
                .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 15_000)
                .compress(false);
        return builder
                .clientConnector(new ReactorClientHttpConnector(httpClient))
                .baseUrl(BACKEND)
                .build();
    }

    @Bean
    public RouterFunction<ServerResponse> passthroughRoute(WebClient backendClient) {
        return route(POST("/passthrough"), request -> {
            MediaType contentType = request.headers().contentType()
                    .orElse(MediaType.TEXT_PLAIN);
            return request.bodyToMono(byte[].class)
                    .defaultIfEmpty(new byte[0])
                    .flatMap(body -> backendClient.post()
                            .contentType(contentType)
                            .bodyValue(body)
                            .exchangeToMono(resp -> {
                                MediaType backendType = resp.headers().contentType()
                                        .orElse(MediaType.TEXT_PLAIN);
                                return resp.bodyToMono(byte[].class)
                                        .defaultIfEmpty(new byte[0])
                                        .flatMap(data -> ServerResponse
                                                .status(resp.statusCode())
                                                .contentType(backendType)
                                                .bodyValue(data));
                            }))
                    .onErrorResume(err -> ServerResponse.status(502)
                            .contentType(MediaType.TEXT_PLAIN)
                            .bodyValue(String.valueOf(err.getMessage())));
        });
    }
}
