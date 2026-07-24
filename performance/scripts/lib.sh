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

# lib.sh — reusable helpers for the performance harness.
#
# Provides port probing, process-tree teardown, a background RSS/CPU sampler,
# and a bash-3.2-compatible key/value result store. Sourced by run.sh.
#
# All helpers avoid `nc` (port checks use bash /dev/tcp) and associative arrays
# (mangled indirect variables) so the harness runs on the stock macOS bash 3.2
# as well as modern Linux bash.

# ── Port-open probe ───────────────────────────────────────────────────────────
# Returns 0 if something is listening on the local port. Tries a fast /dev/tcp
# connect on both address families — IPv4 (127.0.0.1) for most runtimes and IPv6
# (::1) for the Ballerina http:Listener, which binds IPv6-only (*:port) and so is
# unreachable over 127.0.0.1. Both attempts fail-fast on a closed port (a refused
# connect returns in <1ms), so this is cheap enough to poll on a tight interval.
# lsof stays as a last-resort, family-agnostic fallback but is rarely reached.
port_open() {
    (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && return 0
    (exec 3<>"/dev/tcp/::1/$1") 2>/dev/null && return 0
    lsof -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

# ── Wait until a port starts accepting connections ────────────────────────────
wait_for_port() {
    local port="$1"
    local timeout_sec="${2:-60}"
    # Poll every 0.1s; track iterations as integer tenths-of-a-second to avoid
    # spawning bc on every loop. max_ticks = timeout_sec * 10.
    local ticks=0
    local max_ticks=$(( timeout_sec * 10 ))
    while ! port_open "$port"; do
        sleep 0.1
        ticks=$(( ticks + 1 ))
        if (( ticks > max_ticks )); then
            echo "ERROR: port $port did not open within ${timeout_sec}s" >&2
            return 1
        fi
    done
}

# ── Wait until a port stops accepting connections ─────────────────────────────
wait_port_close() {
    local port="$1"
    local i=0
    while port_open "$port"; do
        sleep 0.1
        i=$(( i + 1 ))
        if (( i >= 100 )); then
            echo "WARNING: port $port still open after 10s" >&2
            break
        fi
    done
}

# ── Wait for a launched service to start listening, fast-failing on crash ─────
# Args: PID PORT [timeout_sec]. Returns 0 once the port accepts connections.
# If the launched process dies before the port opens, a short grace window still
# allows a forked child (e.g. `bal run`, `go run`) to bind; otherwise fails fast.
wait_for_service() {
    local pid="$1" port="$2" timeout_sec="${3:-120}"
    local ticks=0 dead_grace=0
    # Poll at 5ms: a refused /dev/tcp connect costs <1ms, so this tightens
    # startup-timing resolution from ~100ms to single-digit ms without
    # meaningful CPU cost (a ready service is detected in ~20 probes).
    local max_ticks=$(( timeout_sec * 200 ))
    while ! port_open "$port"; do
        if ! kill -0 "$pid" 2>/dev/null; then
            dead_grace=$(( dead_grace + 1 ))
            (( dead_grace > 400 )) && return 1   # ~2s grace for fork handoff
        fi
        sleep 0.005
        ticks=$(( ticks + 1 ))
        (( ticks > max_ticks )) && return 1
    done
    return 0
}

# ── Force-kill everything listening on a port ─────────────────────────────────
force_kill_port() {
    local port="$1"
    local pids
    pids=$(lsof -ti tcp:"$port" 2>/dev/null || true)
    local pid
    for pid in $pids; do
        kill -9 "$pid" 2>/dev/null || true
    done
}

# ── Kill a process tree (for launchers like `go run` / `bal run` that fork) ───
kill_tree() {
    local pid="$1"
    local children
    children=$(pgrep -P "$pid" 2>/dev/null || true)
    local child
    for child in $children; do
        kill_tree "$child" 2>/dev/null || true
    done
    kill "$pid" 2>/dev/null || true
}

# ── Result store: mangled indirect variables (bash 3.2, no associative arrays) ─
# Keys are mangled to valid identifiers. Reads of an unset key return "N/A".
_mangle() { echo "${1//[-,.]/_}"; }

_store() {
    local prefix="$1" key="$2" val="$3"
    local varname="${prefix}__$(_mangle "$key")"
    printf -v "$varname" '%s' "$val"
}

_fetch() {
    local prefix="$1" key="$2"
    local varname="${prefix}__$(_mangle "$key")"
    # `:-` on the indirect expansion: under `set -u`, ${!varname} of an unset
    # var aborts the script, so the fallback must be on this line (e.g. a metric
    # that was never stored because a payload file was missing).
    local val="${!varname:-}"
    echo "${val:-N/A}"
}

# ── Resource monitor: background loop writing "TOTAL_RSS_KB TOTAL_CPU_PCT" ─────
# Discovers the actual listening process via lsof on each tick, so launcher
# processes that exit after spawning the server (e.g. `go run`, `bal run`) do
# not cause the monitor to see wrong data or exit prematurely. The loop exits
# when the monitored port stops accepting connections.
#
# Args: $1 = port to monitor. Sets MONITOR_PID and MONITOR_FILE.
start_monitor() {
    local port="$1"
    MONITOR_FILE=$(mktemp /tmp/perf-monitor-XXXXXX)
    (
        while true; do
            # Find the PID with an active LISTEN socket on the port. head -1 keeps
            # server_pid a clean integer (avoids word-splitting in the ps args).
            server_pid=$(lsof -ti "tcp:$port" -sTCP:LISTEN 2>/dev/null | head -1 || true)
            # Exit once the server has stopped listening (crash or clean shutdown).
            [[ -z "$server_pid" ]] && break
            # Include immediate children so wrapper processes (e.g. the `go run`
            # parent) don't hide the actual server binary's resource usage.
            child_pids=$(pgrep -P "$server_pid" 2>/dev/null || true)
            all_pids="$server_pid"
            if [[ -n "$child_pids" ]]; then
                all_pids="$all_pids,$(echo "$child_pids" | tr '\n' ',' | sed 's/,$//')"
            fi
            # Aggregate RSS and CPU across all processes; emit one line per sample.
            ps -p "$all_pids" -o rss=,"%cpu=" 2>/dev/null | \
                awk 'NF>=2 {rss+=$1+0; cpu+=$2+0} END {if(NR>0) printf "%d %.1f\n",rss,cpu}' \
                || true
            sleep 0.1
        done
    ) >> "$MONITOR_FILE" &
    MONITOR_PID=$!
}

stop_monitor() {
    if [[ -n "${MONITOR_PID:-}" ]]; then
        kill "$MONITOR_PID" 2>/dev/null || true
        wait "$MONITOR_PID" 2>/dev/null || true   # collect exit status; suppress "Terminated"
        MONITOR_PID=""
    fi
}

# Prints "MAX_RSS_MB MAX_CPU_PCT" from MONITOR_FILE then removes it.
read_monitor_maxes() {
    if [[ -z "${MONITOR_FILE:-}" || ! -f "$MONITOR_FILE" ]]; then
        echo "0 0"
        return
    fi
    awk '
        NF>=2 {
            rss=$1+0; cpu=$2+0
            if (rss > max_rss) max_rss = rss
            if (cpu > max_cpu) max_cpu = cpu
        }
        END { printf "%.1f %.1f\n", max_rss/1024, max_cpu }
    ' "$MONITOR_FILE"
    rm -f "$MONITOR_FILE"
    MONITOR_FILE=""
}
