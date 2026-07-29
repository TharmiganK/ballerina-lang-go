#!/usr/bin/env bash

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

# run.sh — HTTP performance benchmark orchestrator.
#
# Launches each runtime's service as a native process, drives load with wrk,
# samples RSS/CPU, and writes a Markdown report. See performance/README.md.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/scripts/lib.sh"
# shellcheck source=scripts/parse_wrk.sh
source "$SCRIPT_DIR/scripts/parse_wrk.sh"

# ── Paths / ports ─────────────────────────────────────────────────────────────
SERVICE_PORT=9090
BACKEND_PORT=8688
BACKEND_JAR="$SCRIPT_DIR/backend/target/perf-backend.jar"
GATEWAY_JAR="$SCRIPT_DIR/services/java-netty/target/perf-gateway.jar"
GATEWAY_NATIVE="$SCRIPT_DIR/services/java-netty/target/perf-gateway-native"
SPRING_JAR="$SCRIPT_DIR/services/java-spring/target/perf-spring.jar"
DOTNET_DLL="$SCRIPT_DIR/services/dotnet/bin/publish/perf-dotnet.dll"
# Native AOT build of the same dotnet service: a self-contained native binary
# (no managed .dll / `dotnet` host), published into its own dir so it never
# clobbers the managed publish/ that the `dotnet` runtime launches.
DOTNET_AOT_BIN="$SCRIPT_DIR/services/dotnet/bin/publish-aot/perf-dotnet"
GO_BIN_DIR="$SCRIPT_DIR/services/go/bin"
RUST_BIN_DIR="$SCRIPT_DIR/services/rust/target/release"
# GraalVM native images built from the Ballerina services land beside their
# source as $BAL_DIR/<stem> (e.g. services/ballerina/hello). git-ignored.
BAL_NATIVE_DIR="$SCRIPT_DIR/services/ballerina"
# Nutcracker `bal build` executables land in their own subdir so they never
# clobber swanlake-graalvm's images, which share $BAL_NATIVE_DIR/<stem>.
NUT_NATIVE_DIR="$SCRIPT_DIR/services/ballerina/nutcracker-native"
# SwanLake `bal build` produces an executable jar per scenario, kept in its own
# subdir and launched with `java -jar` (rather than recompiling on every run).
SWAN_JAR_DIR="$SCRIPT_DIR/services/ballerina/swanlake-jar"
PAYLOAD_DIR="$SCRIPT_DIR/payloads"
LUA_SCRIPT="$SCRIPT_DIR/scripts/post_payload.lua"
BAL_DIR="$SCRIPT_DIR/services/ballerina"

# Two distinct `bal` binaries: Nutcracker is this repo's build; SwanLake is the
# jBallerina distribution on PATH (override with SWAN_BAL=/path/to/bal).
NUT_BAL="${NUT_BAL:-$REPO_ROOT/bal}"
SWAN_BAL="${SWAN_BAL:-bal}"

# ── Defaults ──────────────────────────────────────────────────────────────────
SCENARIO_FILTER="all"
RUNTIME_FILTER="default"
USERS="100,200,500"
PAYLOADS="1KB,10KB,50KB"
WARMUP="30s"
DURATION="60s"
THREADS=""
OUTPUT=""
STARTUP_RUNS="3"   # cold-start the service this many times; report the min
FORCE=false        # --force: rebuild every artifact even if it already exists

# ── Cold-start / warmup curve ─────────────────────────────────────────────────
# Off by default. When on, each (scenario, runtime) also reports startup RSS and
# a warmup curve — throughput over back-to-back short windows from a cold process
# with no discarded warmup. This is the regime where AOT beats JIT: cloud
# scale-to-zero / autoscaling has no warmup window, so request #1 is what ships.
COLD_START=false
COLD_START_ONLY=false # --cold-start-only: run just the cold-start metrics, skip
                      # the steady-state grid entirely (implies --cold-start)
COLD_WINDOWS="10"    # number of back-to-back measured windows
COLD_WINDOW="1s"     # wrk duration per window (the curve's time resolution)
COLD_USERS="50"      # concurrency held constant across the curve
COLD_PAYLOAD="1KB"   # passthrough payload for the curve (ignored for hello)
BACKEND_WARMUP="5s"  # pre-warm the JVM backend so the first-measured runtime
                     # isn't charged for the backend's own cold-start (passthrough)

ALL_RUNTIMES=(nutcracker nutcracker-run swanlake swanlake-graalvm go rust node node-express bun python python-flask python-fastapi java-netty graalvm-netty java-spring dotnet dotnet-aot)
# Default: the recommended Ballerina runtime (the `bal build` executable, named
# `nutcracker`) vs one industry-leading stack per language. The interpreted
# `bal run` variant (`nutcracker-run`), the stdlib/legacy baselines, and the
# remaining native-image variants stay behind --runtimes all (or an explicit list).
DEFAULT_RUNTIMES=(nutcracker swanlake go rust java-spring dotnet node python-fastapi)
ALL_SCENARIOS=(hello-service passthrough)

# Scenario → service file/module stem. The scenario id is user-facing (and can
# contain hyphens); the stem must be a valid filename AND Python module name, so
# hello-service maps to the hello.* service files.
scenario_stem() { case "$1" in hello-service) echo "hello" ;; *) echo "$1" ;; esac; }

# ── CPU count (for wrk threads / gunicorn workers) ────────────────────────────
CORES="$( (command -v nproc >/dev/null && nproc) || sysctl -n hw.ncpu 2>/dev/null || echo 4)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]
  --scenario  TYPE   hello-service | passthrough | all    (default: $SCENARIO_FILTER)
  --runtimes  LIST   comma list from: ${ALL_RUNTIMES[*]}
                     or: all | default (= ${DEFAULT_RUNTIMES[*]})   (default: $RUNTIME_FILTER)
  --users     LIST   concurrent connections, comma list  (default: $USERS)
  --payloads  LIST   passthrough payload sizes           (default: $PAYLOADS)
  --warmup    DUR     warmup duration per run (wrk -d)     (default: $WARMUP)
  --duration  DUR     measured duration per run (wrk -d)   (default: $DURATION)
  --threads   N      wrk threads (default: min(cores,users))
  --output    FILE   Markdown report path (default: results/perf-report-<ts>.md)
  --startup-runs N   cold starts per runtime; report the min (default: $STARTUP_RUNS)
  --cold-start       also measure startup RSS + a cold warmup curve (AOT vs JIT)
  --cold-start-only  run ONLY the cold-start metrics; skip the steady-state grid
  --cold-windows N   warmup-curve windows of $COLD_WINDOW each (default: $COLD_WINDOWS)
  --cold-users N     concurrency held across the warmup curve (default: $COLD_USERS)
  --force            rebuild every artifact (incl. Nutcracker bal) from scratch

Env: NUT_BAL (Nutcracker bal, default <repo>/bal), SWAN_BAL (jBallerina bal, default 'bal').
EOF
    exit "${1:-1}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scenario) SCENARIO_FILTER="$2"; shift 2 ;;
        --runtimes) RUNTIME_FILTER="$2"; shift 2 ;;
        --users)    USERS="$2";          shift 2 ;;
        --payloads) PAYLOADS="$2";       shift 2 ;;
        --warmup)   WARMUP="$2";         shift 2 ;;
        --duration) DURATION="$2";       shift 2 ;;
        --threads)  THREADS="$2";        shift 2 ;;
        --output)   OUTPUT="$2";         shift 2 ;;
        --startup-runs) STARTUP_RUNS="$2"; shift 2 ;;
        --cold-start)   COLD_START=true;   shift ;;
        --cold-start-only) COLD_START=true; COLD_START_ONLY=true; shift ;;
        --cold-windows) COLD_WINDOWS="$2"; shift 2 ;;
        --cold-users)   COLD_USERS="$2";   shift 2 ;;
        --force)    FORCE=true;          shift ;;
        -h|--help)  usage 0 ;;
        *) echo "Unknown option: $1" >&2; usage ;;
    esac
done

# ── Resolve filters into arrays ───────────────────────────────────────────────
IFS=',' read -r -a USER_LIST    <<< "$USERS"
IFS=',' read -r -a PAYLOAD_LIST <<< "$PAYLOADS"

if [[ "$SCENARIO_FILTER" == "all" ]]; then
    SCENARIO_LIST=("${ALL_SCENARIOS[@]}")
else
    IFS=',' read -r -a SCENARIO_LIST <<< "$SCENARIO_FILTER"
fi

if [[ "$RUNTIME_FILTER" == "all" ]]; then
    RUNTIME_LIST=("${ALL_RUNTIMES[@]}")
elif [[ "$RUNTIME_FILTER" == "default" ]]; then
    RUNTIME_LIST=("${DEFAULT_RUNTIMES[@]}")
else
    IFS=',' read -r -a RUNTIME_LIST <<< "$RUNTIME_FILTER"
fi

[[ -z "$OUTPUT" ]] && OUTPUT="$SCRIPT_DIR/results/perf-report-$(date +%Y%m%d-%H%M%S).md"
mkdir -p "$(dirname "$OUTPUT")"

# ── Validate always-needed tools ──────────────────────────────────────────────
for tool in wrk lsof awk; do
    command -v "$tool" &>/dev/null || { echo "ERROR: '$tool' not found in PATH" >&2; exit 1; }
done

# ── Portable sub-second epoch timer (BSD date has no %N) ──────────────────────
now_s() {
    if [[ -n "${EPOCHREALTIME:-}" ]]; then echo "${EPOCHREALTIME/,/.}"; return; fi
    python3 -c 'import time;print("%.6f"%time.time())' 2>/dev/null && return
    date +%s
}
elapsed_s() { awk "BEGIN{printf \"%.3f\", $2-$1}"; }

# ── Process handles + cleanup ─────────────────────────────────────────────────
SERVICE_PID=""
BACKEND_PID=""
MONITOR_PID=""
MONITOR_FILE=""

cleanup() {
    [[ -n "$MONITOR_PID" ]] && kill "$MONITOR_PID" 2>/dev/null || true
    [[ -n "$SERVICE_PID" ]] && kill_tree "$SERVICE_PID" 2>/dev/null || true
    [[ -n "$BACKEND_PID" ]] && kill_tree "$BACKEND_PID" 2>/dev/null || true
    [[ -n "$MONITOR_FILE" ]] && rm -f "$MONITOR_FILE" || true
    force_kill_port "$SERVICE_PORT" 2>/dev/null || true
    force_kill_port "$BACKEND_PORT" 2>/dev/null || true
    wait_port_close "$SERVICE_PORT" 2>/dev/null || true
    wait_port_close "$BACKEND_PORT" 2>/dev/null || true
}
trap cleanup EXIT

# ── Build steps for the selected runtimes ─────────────────────────────────────
have_runtime() {
    local target="$1" rt
    for rt in "${RUNTIME_LIST[@]}"; do [[ "$rt" == "$target" ]] && return 0; done
    return 1
}

# Rebuild an artifact if it is missing, or unconditionally when --force is set.
should_build() {
    [[ "$FORCE" == true || ! -e "$1" ]]
}

# .NET Native AOT ILCompiler packages are published only for *portable* RIDs
# (linux-x64, linux-arm64, osx-arm64, …), not the distro-specific RID that
# `dotnet --info` reports on some hosts — e.g. amzn.2023-x64 on Amazon Linux,
# for which no `runtime.amzn.2023-x64.Microsoft.DotNet.ILCompiler` package
# exists on nuget.org. Derive the portable RID from uname instead.
dotnet_portable_rid() {
    local os arch
    case "$(uname -s)" in
        Darwin) os=osx ;;
        *)      os=linux ;;
    esac
    case "$(uname -m)" in
        arm64|aarch64) arch=arm64 ;;
        *)             arch=x64 ;;
    esac
    echo "$os-$arch"
}

ensure_backend() {
    if should_build "$BACKEND_JAR"; then
        echo "  Building Netty backend (mvn)..."
        (cd "$SCRIPT_DIR/backend" && mvn -q -DskipTests package)
    fi
}

# Verify (and, when needed, build) the Nutcracker `bal` used by the nutcracker
# and nutcracker-run runtimes. The default is this repo's ./bal, which is
# built on demand (or rebuilt under --force); an externally-provided NUT_BAL is
# not ours to build, so it is only verified to exist.
ensure_nutcracker_bal() {
    have_runtime nutcracker || have_runtime nutcracker-run || return 0
    if [[ "$NUT_BAL" != "$REPO_ROOT/bal" ]]; then
        [[ -x "$NUT_BAL" ]] || { echo "ERROR: NUT_BAL '$NUT_BAL' is not an executable." >&2; return 1; }
        return 0
    fi
    if should_build "$NUT_BAL"; then
        command -v go >/dev/null || { echo "ERROR: building the Nutcracker bal needs 'go' on PATH." >&2; return 1; }
        echo "  Building Nutcracker bal ($NUT_BAL)..."
        (cd "$REPO_ROOT" && go build -o "$NUT_BAL" ./cli/cmd) \
            || { echo "ERROR: failed to build the Nutcracker bal." >&2; return 1; }
    fi
    [[ -x "$NUT_BAL" ]] || { echo "ERROR: Nutcracker bal not found at '$NUT_BAL' (build it with: go build -o bal ./cli/cmd)." >&2; return 1; }
}

ensure_builds() {
    ensure_nutcracker_bal || return 1
    if have_runtime go; then
        echo "  Building Go services..."
        mkdir -p "$GO_BIN_DIR"
        (cd "$SCRIPT_DIR/services/go" && go build -o "$GO_BIN_DIR/hello" ./hello && go build -o "$GO_BIN_DIR/passthrough" ./passthrough)
    fi
    if { have_runtime java-netty || have_runtime graalvm-netty; } && should_build "$GATEWAY_JAR"; then
        echo "  Building Netty gateway (mvn)..."
        (cd "$SCRIPT_DIR/services/java-netty" && mvn -q -DskipTests package)
    fi
    if have_runtime graalvm-netty; then
        if ! command -v native-image >/dev/null; then
            echo "  WARNING: graalvm-netty needs GraalVM 'native-image' on PATH (install a GraalVM JDK); skipping build." >&2
        elif should_build "$GATEWAY_NATIVE"; then
            echo "  Building Netty gateway native image (native-image; slow)..."
            # Netty 4.1.x ships native-image reachability metadata inside its
            # jars, so a plain --no-fallback build works from the shaded jar.
            native-image --no-fallback -jar "$GATEWAY_JAR" "$GATEWAY_NATIVE" \
                > /tmp/perf-native-gateway.log 2>&1 \
                || { echo "  WARNING: native-image build failed (see /tmp/perf-native-gateway.log); graalvm-netty will be skipped." >&2; rm -f "$GATEWAY_NATIVE"; }
        fi
    fi
    if have_runtime nutcracker; then
        # `bal build` packs onto a "balrt" runner stub. Local (repo) bal builds
        # resolve a flat balrt sibling next to the bal binary; build it if
        # missing. An external NUT_BAL is assumed to ship its own stub.
        local nut_balrt; nut_balrt="$(dirname "$NUT_BAL")/balrt"
        if should_build "$nut_balrt" && [[ -d "$REPO_ROOT/cli/cmd/balrt" ]] && command -v go >/dev/null; then
            echo "  Building Nutcracker runner stub (balrt)..."
            (cd "$REPO_ROOT" && go build -o "$nut_balrt" ./cli/cmd/balrt) \
                || echo "  WARNING: failed to build balrt stub; nutcracker builds may fail." >&2
        fi
        mkdir -p "$NUT_NATIVE_DIR"
        local scn stem
        for scn in "${SCENARIO_LIST[@]}"; do
            stem="$(scenario_stem "$scn")"
            if should_build "$NUT_NATIVE_DIR/$stem"; then
                echo "  Building Ballerina executable ($stem via Nutcracker bal build)..."
                "$NUT_BAL" build -o "$NUT_NATIVE_DIR/$stem" "$BAL_DIR/$stem.bal" \
                    > "/tmp/perf-nut-native-$stem.log" 2>&1 \
                    || { echo "  WARNING: Nutcracker bal build failed for $stem (see /tmp/perf-nut-native-$stem.log); nutcracker will be skipped for it." >&2; rm -f "$NUT_NATIVE_DIR/$stem"; }
            fi
        done
    fi
    if have_runtime swanlake; then
        mkdir -p "$SWAN_JAR_DIR"
        local scn stem
        for scn in "${SCENARIO_LIST[@]}"; do
            stem="$(scenario_stem "$scn")"
            if should_build "$SWAN_JAR_DIR/$stem.jar"; then
                echo "  Building Ballerina executable jar ($stem via SwanLake bal build)..."
                "$SWAN_BAL" build -o "$SWAN_JAR_DIR/$stem.jar" "$BAL_DIR/$stem.bal" \
                    > "/tmp/perf-swan-jar-$stem.log" 2>&1 \
                    || { echo "  WARNING: SwanLake bal build failed for $stem (see /tmp/perf-swan-jar-$stem.log); swanlake will be skipped for it." >&2; rm -f "$SWAN_JAR_DIR/$stem.jar"; }
            fi
        done
    fi
    if have_runtime swanlake-graalvm; then
        if ! command -v native-image >/dev/null; then
            echo "  WARNING: swanlake-graalvm needs GraalVM 'native-image' on PATH; skipping build." >&2
        else
            local scn stem
            for scn in "${SCENARIO_LIST[@]}"; do
                stem="$(scenario_stem "$scn")"
                if should_build "$BAL_NATIVE_DIR/$stem"; then
                    echo "  Building Ballerina native image ($stem via bal --graalvm; slow)..."
                    ( cd "$BAL_NATIVE_DIR" && "$SWAN_BAL" build --graalvm "$stem.bal" ) \
                        > "/tmp/perf-native-bal-$stem.log" 2>&1 \
                        || { echo "  WARNING: bal --graalvm build failed for $stem (see /tmp/perf-native-bal-$stem.log); swanlake-graalvm will be skipped for it." >&2; rm -f "$BAL_NATIVE_DIR/$stem"; }
                fi
            done
        fi
    fi
    if have_runtime rust; then
        if command -v cargo >/dev/null; then
            echo "  Building Rust services (cargo, release)..."
            (cd "$SCRIPT_DIR/services/rust" && cargo build --release --quiet)
        else
            echo "  WARNING: rust needs 'cargo' on PATH (install via rustup); rust will fail to start." >&2
        fi
    fi
    if have_runtime java-spring && should_build "$SPRING_JAR"; then
        echo "  Building Spring Boot gateway (mvn)..."
        (cd "$SCRIPT_DIR/services/java-spring" && mvn -q -DskipTests package)
    fi
    if have_runtime dotnet && should_build "$DOTNET_DLL"; then
        echo "  Building ASP.NET Core gateway (dotnet publish)..."
        (cd "$SCRIPT_DIR/services/dotnet" && dotnet publish -c Release -o bin/publish --nologo -v quiet)
    fi
    if have_runtime dotnet-aot && should_build "$DOTNET_AOT_BIN"; then
        if ! command -v clang >/dev/null; then
            echo "  WARNING: dotnet-aot needs a C toolchain (clang/ld) for Native AOT; skipping build." >&2
        else
            # Native AOT needs an explicit, portable RID (osx-arm64, linux-x64, …).
            local dotnet_rid; dotnet_rid=$(dotnet_portable_rid)
            echo "  Building ASP.NET Core gateway native image (dotnet publish -p:PublishAot; slow)..."
            (cd "$SCRIPT_DIR/services/dotnet" && dotnet publish -c Release -r "$dotnet_rid" \
                -p:PublishAot=true --self-contained -o bin/publish-aot --nologo -v quiet) \
                > /tmp/perf-dotnet-aot.log 2>&1 \
                || { echo "  WARNING: dotnet Native AOT publish failed (see /tmp/perf-dotnet-aot.log); dotnet-aot will be skipped." >&2; rm -f "$DOTNET_AOT_BIN"; }
        fi
    fi
    if have_runtime bun && ! command -v bun >/dev/null; then
        echo "  WARNING: bun not found on PATH (install from https://bun.sh); bun will fail to start." >&2
    fi
    if have_runtime node-express && should_build "$SCRIPT_DIR/services/node-express/node_modules"; then
        echo "  Installing node-express deps (npm)..."
        (cd "$SCRIPT_DIR/services/node-express" && npm install --silent)
    fi
    if have_runtime python-flask; then
        python3 -c 'import flask, requests, waitress' 2>/dev/null || {
            echo "  WARNING: python-flask deps missing. Install with:" >&2
            echo "           pip install -r $SCRIPT_DIR/services/python-flask/requirements.txt" >&2
        }
    fi
    if have_runtime python-fastapi; then
        python3 -c 'import fastapi, uvicorn, aiohttp' 2>/dev/null || {
            echo "  WARNING: python-fastapi deps missing. Install with:" >&2
            echo "           pip install -r $SCRIPT_DIR/services/python-fastapi/requirements.txt" >&2
        }
    fi
}

# ── Start the shared backend (passthrough only) ───────────────────────────────
start_backend() {
    ensure_backend
    echo "  Starting backend on port $BACKEND_PORT..."
    java -jar "$BACKEND_JAR" --ssl false --http2 false > /tmp/perf-backend.log 2>&1 &
    BACKEND_PID=$!
    wait_for_port "$BACKEND_PORT" 30
    echo "  Backend ready (PID $BACKEND_PID)"
    warm_backend
}

# Warm the backend JVM before any runtime is measured. The backend is a cold
# JVM that JITs on its first requests, so without this the runtime measured
# first pays a ~20ms backend penalty that later runtimes — hitting an already-hot
# backend — never see, skewing the cold-start first-request metric (and the first
# runtime's warmup curve). A short wrk burst against the echo endpoint tiers up
# its hot path. Gated on --cold-start; steady-state runs discard their own warmup
# and so are unaffected either way.
warm_backend() {
    [[ "$COLD_START" == true ]] || return 0
    command -v wrk >/dev/null || return 0
    echo "  Warming backend JVM (${BACKEND_WARMUP})..."
    local pfile="$PAYLOAD_DIR/${COLD_PAYLOAD}.txt"
    if [[ -f "$pfile" ]]; then
        PAYLOAD_FILE="$pfile" wrk -t2 -c10 -d"$BACKEND_WARMUP" -s "$LUA_SCRIPT" \
            "http://localhost:$BACKEND_PORT/" >/dev/null 2>&1 || true
    else
        wrk -t2 -c10 -d"$BACKEND_WARMUP" "http://localhost:$BACKEND_PORT/" >/dev/null 2>&1 || true
    fi
}

SERVICE_LOG=/tmp/perf-service.log

# Launch "$2..." in $1 as a new session leader, backgrounded. The session
# leader's PID (stable, since perl setsid()s then exec()s in place) is both the
# tracked PID and the process-group id, so the whole tree — including a gunicorn
# master and its forked workers — is torn down with a single group signal. macOS
# has no setsid(1), so perl provides it portably.
session_spawn() {
    local workdir="$1"; shift
    perl -MPOSIX -e 'chdir(shift) or die "chdir: $!"; POSIX::setsid(); exec @ARGV or die "exec: $!"' \
        -- "$workdir" "$@" > "$SERVICE_LOG" 2>&1 &
    SERVICE_PID=$!
    # Drop the job from the shell's table so its later SIGTERM/SIGKILL (once per
    # measured run now that services restart) doesn't print "Terminated" noise.
    # Teardown is by PID/PGID, so disowning does not affect it.
    disown "$SERVICE_PID" 2>/dev/null || true
}

# ── Spawn one runtime service in the background; sets SERVICE_PID ─────────────
launch_service() {
    local rt="$1" scn="$2" stem="$3"
    case "$rt" in
        nutcracker)       session_spawn "." "$NUT_NATIVE_DIR/$stem" ;;
        nutcracker-run)   session_spawn "." "$NUT_BAL" run "$BAL_DIR/$stem.bal" ;;
        swanlake)         session_spawn "." java -jar "$SWAN_JAR_DIR/$stem.jar" ;;
        swanlake-graalvm) session_spawn "." "$BAL_NATIVE_DIR/$stem" ;;
        go)               session_spawn "." "$GO_BIN_DIR/$stem" ;;
        rust)             session_spawn "." "$RUST_BIN_DIR/$stem" ;;
        node)         session_spawn "." node "$SCRIPT_DIR/services/node/$stem.js" ;;
        bun)          session_spawn "." bun "$SCRIPT_DIR/services/bun/$stem.js" ;;
        node-express) session_spawn "$SCRIPT_DIR/services/node-express" node "$stem.js" ;;
        python)       session_spawn "." python3 "$SCRIPT_DIR/services/python/$stem.py" ;;
        python-flask)
            # waitress: single-process, multithreaded, production WSGI server.
            # Single process ⇒ clean, race-free teardown (unlike a forking
            # gunicorn master). Falls back to Flask's threaded dev server.
            if command -v waitress-serve >/dev/null; then
                session_spawn "$SCRIPT_DIR/services/python-flask" \
                    waitress-serve --host=0.0.0.0 --port="$SERVICE_PORT" --threads="$(( CORES * 4 ))" "$stem:app"
            else
                session_spawn "$SCRIPT_DIR/services/python-flask" python3 "$stem.py"
            fi ;;
        python-fastapi)
            # uvicorn with uvloop + httptools ("Python done well"). One worker
            # per core: a single worker is GIL-bound to ~1 core, and multi-worker
            # is how uvicorn is deployed in production — matching the multi-core
            # parity of the other runtimes. The forking master and its workers
            # share a process group, so stop_service tears them down together.
            session_spawn "$SCRIPT_DIR/services/python-fastapi" \
                python3 -m uvicorn --host 0.0.0.0 --port "$SERVICE_PORT" \
                --workers "$CORES" --loop uvloop --http httptools \
                --no-access-log --log-level warning "$stem:app" ;;
        java-netty)   session_spawn "." java -jar "$GATEWAY_JAR" --scenario "$scn" --port "$SERVICE_PORT" ;;
        graalvm-netty) session_spawn "." "$GATEWAY_NATIVE" --scenario "$scn" --port "$SERVICE_PORT" ;;
        java-spring)  session_spawn "." java -jar "$SPRING_JAR" --scenario="$stem" --server.port="$SERVICE_PORT" ;;
        dotnet)       session_spawn "." dotnet "$DOTNET_DLL" --scenario "$stem" --port "$SERVICE_PORT" ;;
        dotnet-aot)   session_spawn "." "$DOTNET_AOT_BIN" --scenario "$stem" --port "$SERVICE_PORT" ;;
        *) echo "Unknown runtime: $rt" >&2; return 1 ;;
    esac
}

# ── Launch a runtime service; prints startup seconds (min of STARTUP_RUNS) ────
# Cold-starts the service STARTUP_RUNS times, timing each launch→port-open span,
# and reports the minimum — startup is a "how fast can it cold-start" metric, so
# the min rejects run-to-run OS scheduling / cold-cache noise. The intermediate
# starts are torn down; the final launch is left listening for the load run.
start_service() {
    local rt="$1" scn="$2"
    local start end elapsed
    local stem; stem="$(scenario_stem "$scn")"
    local runs="${STARTUP_RUNS:-3}"
    [[ "$runs" =~ ^[0-9]+$ ]] || runs=3
    (( runs < 1 )) && runs=1

    if port_open "$SERVICE_PORT"; then
        echo "ERROR: port $SERVICE_PORT already in use" >&2
        return 1
    fi

    local best="" i
    for (( i = 1; i <= runs; i++ )); do
        start=$(now_s)
        launch_service "$rt" "$scn" "$stem" || return 1
        if ! wait_for_service "$SERVICE_PID" "$SERVICE_PORT" 120; then
            echo "    ── service log ─────────────────────────────" >&2
            tail -20 "$SERVICE_LOG" 2>/dev/null | sed 's/^/    /' >&2
            echo "0"
            return 1
        fi
        end=$(now_s)
        elapsed=$(elapsed_s "$start" "$end")
        best=$(awk -v a="$best" -v b="$elapsed" 'BEGIN { if (a == "" || b + 0 < a + 0) print b; else print a }')
        # Tear down every start but the last so the next cold start is clean; the
        # final launch stays up for the caller's monitor + load runs.
        (( i < runs )) && stop_service
    done
    echo "$best"
}

stop_service() {
    if [[ -n "$SERVICE_PID" ]]; then
        # Signal the whole process group (negative PID): master + workers die
        # together, so no forking master can respawn a worker mid-teardown.
        kill -TERM -- "-$SERVICE_PID" 2>/dev/null || kill -TERM "$SERVICE_PID" 2>/dev/null || true
        sleep 0.3
        kill -KILL -- "-$SERVICE_PID" 2>/dev/null || true
        SERVICE_PID=""
    fi
    force_kill_port "$SERVICE_PORT"
    wait_port_close "$SERVICE_PORT"
}

# ── Cold-start a fresh instance for an independent measured run ───────────────
# Tears down the current instance and launches a new one, waiting until it is
# listening. Unlike start_service it does no startup timing / best-of-N — that
# is measured once per (scenario, runtime); this just gives each user-count /
# payload its own process so measurements (especially memory, whose heaps are
# high-water-mark) don't inherit state from earlier runs.
restart_service() {
    local rt="$1" scn="$2" stem="$3"
    stop_service
    launch_service "$rt" "$scn" "$stem" || return 1
    wait_for_service "$SERVICE_PID" "$SERVICE_PORT" 120 || return 1
}

# ── Run wrk once; prints the parsed metrics line ──────────────────────────────
# Args: scenario, users, threads, payload_file (empty for hello), duration
run_wrk() {
    local scn="$1" users="$2" threads="$3" pfile="$4" dur="$5"
    local out
    out=$(mktemp /tmp/perf-wrk-XXXXXX)
    if [[ "$scn" == "hello-service" ]]; then
        wrk -t"$threads" -c"$users" -d"$dur" --latency \
            "http://localhost:$SERVICE_PORT/hello" > "$out" 2>&1 || true
    else
        PAYLOAD_FILE="$pfile" wrk -t"$threads" -c"$users" -d"$dur" --latency \
            -s "$LUA_SCRIPT" "http://localhost:$SERVICE_PORT/passthrough" > "$out" 2>&1 || true
    fi
    parse_wrk "$out"
    rm -f "$out"
}

# ── Time the single first HTTP request against a cold service ─────────────────
# Prints milliseconds (curl's %{time_total}, measured inside libcurl so curl's
# own process startup is excluded) or N/A. Mirrors the load endpoint exactly:
# GET /hello, or POST /passthrough with the payload. The readiness wait is a bare
# TCP probe, so this is the genuine first request — on the JVM it pays class-load
# plus the handler's first-hit JIT that the throughput windows average away.
first_request_latency() {
    local scn="$1" pfile="$2" out code secs
    command -v curl >/dev/null || { echo "N/A"; return; }
    if [[ "$scn" == "hello-service" ]]; then
        out=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' \
            "http://localhost:$SERVICE_PORT/hello" 2>/dev/null || true)
    else
        [[ -n "$pfile" ]] || { echo "N/A"; return; }
        out=$(curl -s -o /dev/null -w '%{http_code} %{time_total}' \
            -X POST -H 'Content-Type: text/plain' --data-binary @"$pfile" \
            "http://localhost:$SERVICE_PORT/passthrough" 2>/dev/null || true)
    fi
    read -r code secs <<< "$out"
    [[ "$code" == 2* && -n "$secs" ]] || { echo "N/A"; return; }
    awk -v s="$secs" 'BEGIN{printf "%.2f", s*1000}'
}

# ── Cold-start metrics ────────────────────────────────────────────────────────
# Runs on the cold instance left listening by start_service (SERVICE_PID set):
# readiness is a bare TCP probe, so the handler is still JIT-cold. Samples startup
# RSS, times the very first HTTP request, then drives COLD_WINDOWS back-to-back
# windows with no discarded warmup, recording throughput per window. AOT runtimes
# are flat from window 1; JIT runtimes ramp as tiers compile — the gap is the
# cold-start penalty steady-state numbers hide. Stores STARTRSS, FIRSTREQ, and a
# space-joined COLDCURVE.
measure_cold_start() {
    local scn="$1" rt="$2"

    local pfile=""
    if [[ "$scn" != "hello-service" ]]; then
        pfile="$PAYLOAD_DIR/${COLD_PAYLOAD}.txt"
        [[ -f "$pfile" ]] || pfile=""
    fi

    local rss_pid rss_kb
    rss_pid=$(lsof -ti "tcp:$SERVICE_PORT" -sTCP:LISTEN 2>/dev/null | head -1 || true)
    if [[ -n "$rss_pid" ]]; then
        rss_kb=$(ps -p "$rss_pid" -o rss= 2>/dev/null | awk '{s+=$1+0} END{print s}')
        _store STARTRSS "$scn,$rt" "$(awk -v k="${rss_kb:-0}" 'BEGIN{printf "%.1f", k/1024}')"
    else
        _store STARTRSS "$scn,$rt" "N/A"
    fi

    _store FIRSTREQ "$scn,$rt" "$(first_request_latency "$scn" "$pfile")"

    local threads="${THREADS:-$(( COLD_USERS < CORES ? COLD_USERS : CORES ))}"
    local curve="" i thr rest
    for (( i = 1; i <= COLD_WINDOWS; i++ )); do
        read -r thr rest < <(run_wrk "$scn" "$COLD_USERS" "$threads" "$pfile" "$COLD_WINDOW" || true)
        curve+="${curve:+ }${thr:-N/A}"
    done
    _store COLDCURVE "$scn,$rt" "$curve"
    echo "  Cold-start: first-req $(_fetch FIRSTREQ "$scn,$rt")ms | RSS $(_fetch STARTRSS "$scn,$rt")MB | curve (req/s): $curve"
}

# ── Main ──────────────────────────────────────────────────────────────────────
echo "============================================================"
echo " HTTP Performance Benchmark"
echo "============================================================"
echo " Scenarios: ${SCENARIO_LIST[*]}"
echo " Runtimes:  ${RUNTIME_LIST[*]}"
if [[ "$COLD_START_ONLY" == true ]]; then
    echo " Mode: cold-start only (no steady-state grid)"
    echo " Cold-start: ${COLD_WINDOWS} x ${COLD_WINDOW} windows @ ${COLD_USERS} users"
else
    echo " Users: $USERS | Warmup: $WARMUP | Duration: $DURATION"
    [[ "$COLD_START" == true ]] && echo " Cold-start: ${COLD_WINDOWS} x ${COLD_WINDOW} windows @ ${COLD_USERS} users"
fi
echo " Payloads (passthrough): $PAYLOADS"
echo " Output: $OUTPUT"
echo "============================================================"

ensure_builds || exit 1

# Start the backend if any passthrough scenario is selected.
for scn in "${SCENARIO_LIST[@]}"; do
    if [[ "$scn" == "passthrough" ]]; then start_backend; break; fi
done

for scn in "${SCENARIO_LIST[@]}"; do
    # hello-service has no payload dimension; use a single sentinel "-".
    if [[ "$scn" == "hello-service" ]]; then
        SCN_PAYLOADS=("-")
    else
        SCN_PAYLOADS=("${PAYLOAD_LIST[@]}")
    fi

    echo ""
    echo "########## Scenario: $scn ##########"

    for rt in "${RUNTIME_LIST[@]}"; do
        echo "──────────────────────────────────────────"
        echo " $scn / $rt"
        echo "──────────────────────────────────────────"

        echo "  Measuring startup time..."
        startup=$(start_service "$rt" "$scn") || startup="N/A"
        _store STARTUP "$scn,$rt" "$startup"
        echo "  Startup: ${startup}s"

        [[ "$startup" == "N/A" ]] && { stop_service; continue; }

        stem="$(scenario_stem "$scn")"
        # start_service left one fresh instance listening; reuse it for the first
        # measured run, then cold-restart before every subsequent one so each
        # user-count / payload is measured on an independent process (heaps are
        # high-water-mark, so a shared process inflates later memory readings).
        reuse_instance=1

        # The cold warmup curve must see a JIT-cold handler, so measure it on this
        # freshly started instance before any load, then cold-restart so the first
        # steady-state run still gets a pristine process.
        if [[ "$COLD_START" == true ]]; then
            measure_cold_start "$scn" "$rt"
            reuse_instance=0
        fi

        # --cold-start-only stops here: the cold-start metrics above are the whole
        # run, so skip the steady-state load grid entirely.
        if [[ "$COLD_START_ONLY" != true ]]; then
        for users in "${USER_LIST[@]}"; do
            local_threads="${THREADS:-$(( users < CORES ? users : CORES ))}"
            for payload in "${SCN_PAYLOADS[@]}"; do
                pfile=""
                if [[ "$payload" != "-" ]]; then
                    pfile="$PAYLOAD_DIR/${payload}.txt"
                    [[ -f "$pfile" ]] || { echo "  WARNING: payload $pfile not found, skipping"; continue; }
                fi

                if [[ "$reuse_instance" != 1 ]]; then
                    if ! restart_service "$rt" "$scn" "$stem"; then
                        echo "    WARNING: service failed to restart; recording N/A for this run" >&2
                        key="$scn,$rt,$users,$payload"
                        for m in THROUGHPUT AVG STDEV P99 MAXLAT ERR MAXMEM MAXCPU; do _store "$m" "$key" "N/A"; done
                        stop_service
                        continue
                    fi
                fi
                reuse_instance=0

                echo "  Users: $users | Payload: $payload | Threads: $local_threads"
                start_monitor "$SERVICE_PORT"

                # Warmup (discarded), then measured run. A failed load run must
                # not abort the whole benchmark, so both tolerate non-zero exits;
                # parse_wrk emits an all-N/A line that is recorded as-is.
                run_wrk "$scn" "$users" "$local_threads" "$pfile" "$WARMUP" >/dev/null || true
                read -r thr avg stdev p99 maxlat err < <(run_wrk "$scn" "$users" "$local_threads" "$pfile" "$DURATION" || true)

                stop_monitor
                read -r maxmem maxcpu <<< "$(read_monitor_maxes)"

                key="$scn,$rt,$users,$payload"
                _store THROUGHPUT "$key" "$thr"
                _store AVG   "$key" "$avg"
                _store STDEV "$key" "$stdev"
                _store P99   "$key" "$p99"
                _store MAXLAT "$key" "$maxlat"
                _store ERR   "$key" "$err"
                _store MAXMEM "$key" "$maxmem"
                _store MAXCPU "$key" "$maxcpu"
                echo "    Throughput: $thr req/s | avg: ${avg}ms | p99: ${p99}ms | stdev: ${stdev}ms | mem: ${maxmem}MB | cpu: ${maxcpu}% | errors: ${err}%"
            done
        done
        fi

        stop_service
    done
done

# ── Generate report ───────────────────────────────────────────────────────────
source "$SCRIPT_DIR/scripts/report.sh"
generate_report > "$OUTPUT"
echo ""
echo "Done. Report written to: $OUTPUT"
