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

# parse_wrk.sh — Extract performance metrics from `wrk --latency` output.
#
# Usage (as a sourced function):
#   source scripts/parse_wrk.sh
#   parse_wrk /path/to/wrk-output.txt
#
# Usage (standalone, from a file or stdin):
#   bash scripts/parse_wrk.sh /path/to/wrk-output.txt
#   wrk --latency ... | bash scripts/parse_wrk.sh
#
# Output format (single space-separated line, all latencies in milliseconds):
#   <throughput_rps> <avg_ms> <stdev_ms> <p99_ms> <max_ms> <err_pct>
#
# Example:
#   38000.00 2.14 1.23 8.20 45.00 0.05
#
# Source lines parsed (wrk must be run with --latency):
#   "    Latency     2.14ms    1.23ms  45.00ms   89.00%"  -> avg, stdev, max
#   "     99%    8.20ms"           (Latency Distribution)  -> p99
#   "Requests/sec:  38000.00"                              -> throughput
#   "  1140000 requests in 30.00s, ..."                    -> total requests
#   "  Socket errors: connect 0, read 12, write 0, timeout 3"  -> errors
#   "  Non-2xx or 3xx responses: 45"                       -> errors
# Error/socket lines are optional; wrk omits them when there were none.

parse_wrk() {
    local input="${1:-/dev/stdin}"

    if [[ "$input" != "/dev/stdin" && ! -f "$input" ]]; then
        echo "parse_wrk: file not found: $input" >&2
        echo "0 N/A N/A N/A N/A 100.00"
        return 1
    fi

    awk '
        # Convert a wrk duration token (e.g. 2.14ms, 890.00us, 1.02s) to milliseconds.
        function to_ms(tok,   num, unit) {
            if (match(tok, /[0-9.]+/)) {
                num = substr(tok, RSTART, RLENGTH) + 0
            } else {
                return 0
            }
            unit = substr(tok, RSTART + RLENGTH)
            if (unit == "us")      return num / 1000.0
            else if (unit == "ms") return num
            else if (unit == "s")  return num * 1000.0
            else if (unit == "m")  return num * 60000.0
            else if (unit == "h")  return num * 3600000.0
            return num   # unitless: assume ms
        }
        # Thread Stats latency row: "Latency  <avg> <stdev> <max> <+/-stdev%>".
        # The digit guard excludes the "Latency Distribution" header line.
        /^[[:space:]]*Latency[[:space:]]+[0-9]/ {
            avg   = to_ms($2)
            stdev = to_ms($3)
            max   = to_ms($4)
            have_lat = 1
        }
        # Latency Distribution p99 row: "99%   <val>"
        /^[[:space:]]*99%[[:space:]]/ {
            p99 = to_ms($2)
            have_p99 = 1
        }
        # Total sample count: "<N> requests in <dur>, <bytes> read"
        /[0-9]+ requests in / {
            total = $1 + 0
        }
        # Socket errors line (optional).
        /Socket errors:/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+,?$/) {
                    v = $i; gsub(/,/, "", v); sock_err += v + 0
                }
            }
        }
        # HTTP error responses (optional).
        /Non-2xx or 3xx responses:/ {
            http_err = $NF + 0
        }
        # Achieved throughput.
        /^Requests\/sec:/ {
            rps = $2 + 0
            have_rps = 1
        }
        END {
            if (!have_lat && !have_rps) {
                print "0 N/A N/A N/A N/A 100.00"
                exit 1
            }
            errs = sock_err + http_err
            err_pct = (total > 0) ? (errs / total) * 100.0 : ((errs > 0) ? 100.0 : 0.0)
            printf "%.2f %s %s %s %s %.2f\n",
                (have_rps ? rps : 0),
                (have_lat ? sprintf("%.2f", avg)   : "N/A"),
                (have_lat ? sprintf("%.2f", stdev) : "N/A"),
                (have_p99 ? sprintf("%.2f", p99)   : "N/A"),
                (have_lat ? sprintf("%.2f", max)   : "N/A"),
                err_pct
        }
    ' "$input"
}

# ── Standalone entry point ────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    parse_wrk "${1:-/dev/stdin}"
fi
