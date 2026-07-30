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

// ASP.NET Core (Kestrel) minimal-API gateway. Serves one of two scenarios on
// the given port: a static hello-world response, or a passthrough that
// forwards POST bodies to the Netty echo backend.

using System.Net;

var scenario = "hello";
var port = 9090;
for (var i = 0; i + 1 < args.Length; i += 2)
{
    switch (args[i])
    {
        case "--scenario": scenario = args[i + 1]; break;
        case "--port": port = int.Parse(args[i + 1]); break;
        default: throw new ArgumentException($"Unknown option: {args[i]}");
    }
}

var builder = WebApplication.CreateBuilder();
builder.Logging.SetMinimumLevel(LogLevel.Warning);
builder.WebHost.ConfigureKestrel(options => options.ListenAnyIP(port));

var app = builder.Build();

if (scenario == "passthrough")
{
    // Shared networking baseline (see performance/README.md): connection
    // reuse, unlimited active connections, 300s idle timeout, 15s connect
    // timeout, TCP_NODELAY on (SocketsHttpHandler default), no
    // decompression. Like Netty's pool, SocketsHttpHandler has no separate
    // idle-connection cap.
    var handler = new SocketsHttpHandler
    {
        MaxConnectionsPerServer = int.MaxValue,
        PooledConnectionIdleTimeout = TimeSpan.FromSeconds(300),
        ConnectTimeout = TimeSpan.FromSeconds(15),
        AutomaticDecompression = DecompressionMethods.None,
    };
    var client = new HttpClient(handler);
    var backend = new Uri("http://localhost:8688/");

    app.MapPost("/passthrough", async (HttpContext ctx) =>
    {
        // Stream the request body straight to the backend — no full-body
        // buffering. Propagate the incoming Content-Length so the forwarded
        // request stays fixed-length (not chunked), matching the other proxies.
        var content = new StreamContent(ctx.Request.Body);
        content.Headers.TryAddWithoutValidation(
            "Content-Type", ctx.Request.ContentType ?? "text/plain");
        if (ctx.Request.ContentLength is long len)
        {
            content.Headers.ContentLength = len;
        }
        var request = new HttpRequestMessage(HttpMethod.Post, backend) { Content = content };

        try
        {
            // ResponseHeadersRead: start forwarding as soon as headers arrive
            // rather than buffering the whole response into memory first.
            using var resp = await client.SendAsync(
                request, HttpCompletionOption.ResponseHeadersRead);
            ctx.Response.StatusCode = (int)resp.StatusCode;
            ctx.Response.ContentType =
                resp.Content.Headers.ContentType?.ToString() ?? "text/plain";
            ctx.Response.ContentLength = resp.Content.Headers.ContentLength;
            await resp.Content.CopyToAsync(ctx.Response.Body);
        }
        catch (HttpRequestException err)
        {
            ctx.Response.StatusCode = 502;
            ctx.Response.ContentType = "text/plain";
            await ctx.Response.Body.WriteAsync(
                System.Text.Encoding.UTF8.GetBytes(err.Message));
        }
    });
}
else
{
    app.MapGet("/hello", (HttpContext ctx) =>
    {
        ctx.Response.ContentType = "text/plain";
        return ctx.Response.WriteAsync("Hello, World!");
    });
}

Console.WriteLine($"{scenario} service (kestrel) listening on :{port} (HTTP/1.1)");
app.Run();
