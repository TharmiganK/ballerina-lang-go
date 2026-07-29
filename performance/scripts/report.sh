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

# report.sh — Markdown report generator for run.sh. Sourced into run.sh so it
# shares the result store (_fetch) and the SCENARIO_LIST/RUNTIME_LIST/USER_LIST/
# PAYLOAD_LIST arrays. Prints the report to stdout.

# Emit one metric row across all runtimes for a given scenario/users/payload.
_metric_row() {
    local label="$1" store="$2" scn="$3" users="$4" payload="$5" rt row
    row="| $label |"
    for rt in "${RUNTIME_LIST[@]}"; do
        row+=" $(_fetch "$store" "$scn,$rt,$users,$payload") |"
    done
    echo "$row"
}

_result_table() {
    local scn="$1" users="$2" payload="$3" rt header sep
    if [[ "$payload" == "-" ]]; then
        echo "### $users Users"
    else
        echo "### $users Users — $payload Payload"
    fi
    echo ""
    header="| Metric |"; sep="|---|"
    for rt in "${RUNTIME_LIST[@]}"; do header+=" $rt |"; sep+="---|"; done
    echo "$header"; echo "$sep"
    _metric_row "Throughput (req/s)"      THROUGHPUT "$scn" "$users" "$payload"
    _metric_row "Avg Latency (ms)"        AVG        "$scn" "$users" "$payload"
    _metric_row "p99 Latency (ms)"        P99        "$scn" "$users" "$payload"
    _metric_row "Latency Std-Dev (ms)"    STDEV      "$scn" "$users" "$payload"
    _metric_row "Max Latency (ms)"        MAXLAT     "$scn" "$users" "$payload"
    _metric_row "Max Memory (MB)"         MAXMEM     "$scn" "$users" "$payload"
    _metric_row "Max CPU (%)"             MAXCPU     "$scn" "$users" "$payload"
    _metric_row "Error Rate (%)"          ERR        "$scn" "$users" "$payload"
    echo ""
}

# Emit the cold-start warmup curve: one row per runtime, one column per window,
# throughput (req/s) from a cold process. AOT holds flat from W1; JIT ramps.
_warmup_curve_table() {
    local scn="$1" rt w header sep curve row
    local -a vals
    echo "### Cold-Start Warmup Curve"
    echo ""
    echo "Throughput (req/s) over $COLD_WINDOWS × $COLD_WINDOW back-to-back windows at $COLD_USERS users, from a cold process with no prior warmup. AOT runtimes hold flat from W1; JIT runtimes ramp as tiers compile — that gap is the cold-start penalty steady-state numbers hide."
    echo ""
    header="| Runtime |"; sep="|---|"
    for (( w = 1; w <= COLD_WINDOWS; w++ )); do header+=" W$w |"; sep+="---|"; done
    echo "$header"; echo "$sep"
    for rt in "${RUNTIME_LIST[@]}"; do
        curve="$(_fetch COLDCURVE "$scn,$rt")"
        row="| $rt |"
        if [[ "$curve" == "N/A" || -z "$curve" ]]; then
            for (( w = 1; w <= COLD_WINDOWS; w++ )); do row+=" N/A |"; done
        else
            read -r -a vals <<< "$curve"
            for (( w = 0; w < COLD_WINDOWS; w++ )); do row+=" ${vals[w]:-N/A} |"; done
        fi
        echo "$row"
    done
    echo ""
}

generate_report() {
    local scn rt users payload wrk_ver
    wrk_ver="$(wrk --version 2>&1 | head -1 || true)"

    echo "# HTTP Performance Benchmark Report"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "## Configuration"
    echo ""
    echo "| Parameter | Value |"
    echo "|---|---|"
    echo "| Scenarios | ${SCENARIO_LIST[*]} |"
    echo "| Runtimes | ${RUNTIME_LIST[*]} |"
    echo "| Concurrent Users | $USERS |"
    echo "| Warmup | $WARMUP |"
    echo "| Duration per run | $DURATION |"
    echo "| Payload Sizes (passthrough) | $PAYLOADS |"
    if [[ "${COLD_START:-false}" == true ]]; then
        echo "| Cold-start curve | $COLD_WINDOWS × $COLD_WINDOW windows @ $COLD_USERS users |"
    fi
    echo "| Load Tool | $wrk_ver |"
    echo "| Backend | perf-backend.jar (Netty, port $BACKEND_PORT) |"
    echo "| Host cores | $CORES |"
    echo ""

    for scn in "${SCENARIO_LIST[@]}"; do
        echo "## Scenario: $scn"
        echo ""
        echo "### Startup Time"
        echo ""
        if [[ "${COLD_START:-false}" == true ]]; then
            echo "| Runtime | Startup (s) | First-request (ms) | Startup RSS (MB) |"
            echo "|---|---|---|---|"
            for rt in "${RUNTIME_LIST[@]}"; do
                echo "| $rt | $(_fetch STARTUP "$scn,$rt") | $(_fetch FIRSTREQ "$scn,$rt") | $(_fetch STARTRSS "$scn,$rt") |"
            done
            echo ""
            _warmup_curve_table "$scn"
        else
            echo "| Runtime | Startup (s) |"
            echo "|---|---|"
            for rt in "${RUNTIME_LIST[@]}"; do
                echo "| $rt | $(_fetch STARTUP "$scn,$rt") |"
            done
            echo ""
        fi

        # --cold-start-only skips the steady-state grid, so there are no per-load
        # result tables to emit.
        if [[ "${COLD_START_ONLY:-false}" != true ]]; then
            local -a scn_payloads
            if [[ "$scn" == "hello-service" ]]; then
                scn_payloads=("-")
            else
                scn_payloads=("${PAYLOAD_LIST[@]}")
            fi

            for users in "${USER_LIST[@]}"; do
                for payload in "${scn_payloads[@]}"; do
                    _result_table "$scn" "$users" "$payload"
                done
            done
        fi
    done

    echo "---"
    echo ""
    echo "_Generated by performance/run.sh (load tool: wrk, closed-loop concurrency). Note: wrk v1 is subject to coordinated omission; tail-latency figures under saturation are optimistic. For open-loop constant-rate testing, use wrk2 (\`-R\`) or k6._"
}
