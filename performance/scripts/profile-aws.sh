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

# profile-aws.sh — one-shot profiler for the Nutcracker hello service.
# Run from the repository root:   bash performance/scripts/profile-aws.sh
# It builds a debug binary, loads the service with wrk, captures CPU/heap/
# block/mutex/goroutine profiles, and writes a single digest to paste back.
#
# Optional env overrides:
#   CONNS=200 DURATION=50 CPUSECS=30 PORT=9090 PPROF=6060 \
#     bash performance/scripts/profile-aws.sh

set -uo pipefail

CONNS="${CONNS:-200}"
DURATION="${DURATION:-50}"
CPUSECS="${CPUSECS:-30}"
PORT="${PORT:-9090}"
PPROF="${PPROF:-6060}"
BAL="performance/services/ballerina/hello.bal"
OUT="perf-profile-$(date +%Y%m%d-%H%M%S)"
PROF_SRC="cli/cmd/prof_debug.go"

say(){ printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

# ── sanity ───────────────────────────────────────────────────────────────────
[[ -f go.mod && -f "$PROF_SRC" && -f "$BAL" ]] || {
  echo "ERROR: run this from the repository root (go.mod, $PROF_SRC, $BAL must exist)"; exit 1; }
for t in go wrk curl awk; do command -v "$t" >/dev/null || { echo "ERROR: '$t' not found"; exit 1; }; done

mkdir -p "$OUT"
echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo '?')  |  output dir: $OUT"

# ── ensure block/mutex profiling is enabled in the debug profiler ────────────
PATCHED=0
if ! grep -q "SetMutexProfileFraction" "$PROF_SRC"; then
  say "Enabling block/mutex profiling in $PROF_SRC (temporary)"
  cp "$PROF_SRC" "$OUT/prof_debug.go.bak"
  perl -0pi -e 's/(\n\tif !p\.enabled \{\n\t\treturn nil\n\t\}\n)/$1\n\truntime.SetBlockProfileRate(10000)\n\truntime.SetMutexProfileFraction(10)\n/' "$PROF_SRC"
  if grep -q "SetMutexProfileFraction" "$PROF_SRC"; then PATCHED=1; else
    echo "WARN: could not auto-patch; block/mutex profiles may be empty"; cp "$OUT/prof_debug.go.bak" "$PROF_SRC"; fi
fi
restore(){ [[ "$PATCHED" == 1 ]] && cp "$OUT/prof_debug.go.bak" "$PROF_SRC" && echo "restored $PROF_SRC"; }

# ── build ────────────────────────────────────────────────────────────────────
say "Building debug binary"
go build -tags debug -o "$OUT/bal-debug" ./cli/cmd || { restore; exit 1; }

# ── free ports, launch service ───────────────────────────────────────────────
for p in "$PORT" "$PPROF"; do
  pids=$(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); [[ -n "$pids" ]] && kill -9 $pids 2>/dev/null; done
sleep 0.5

say "Starting service (GODEBUG=gctrace=1)"
GODEBUG=gctrace=1 "$OUT/bal-debug" run --prof --prof-addr ":$PPROF" "$BAL" \
  >"$OUT/service.out" 2>"$OUT/gctrace.log" &
SVC=$!
trap 'kill -9 $SVC 2>/dev/null; restore' EXIT

# wait for the app port
URLPATH=""
for i in $(seq 1 200); do
  for cand in "/hello" "/hello/"; do
    if curl -s "http://127.0.0.1:$PORT$cand" 2>/dev/null | grep -q Hello; then URLPATH="$cand"; break 2; fi
  done
  sleep 0.1
done
[[ -z "$URLPATH" ]] && { echo "ERROR: service never served Hello on :$PORT"; tail -20 "$OUT/gctrace.log"; exit 1; }
URL="http://127.0.0.1:$PORT$URLPATH"
echo "service up; endpoint = $URL"
curl -s "http://127.0.0.1:$PPROF/debug/pprof/" -o /dev/null -w "pprof endpoint http=%{http_code}\n"

# ── load + capture ───────────────────────────────────────────────────────────
say "Load: wrk -t4 -c$CONNS -d${DURATION}s (capturing during it)"
wrk -t4 -c"$CONNS" -d"${DURATION}s" --latency "$URL" >"$OUT/wrk.txt" 2>&1 &
WRK=$!
sleep 5
# per-core OS view (best effort)
MPSTAT=""
if command -v mpstat >/dev/null; then mpstat -P ALL 1 "$CPUSECS" >"$OUT/mpstat.txt" 2>&1 & MPSTAT=$!; fi
# CPU profile blocks for CPUSECS
curl -s "http://127.0.0.1:$PPROF/debug/pprof/profile?seconds=$CPUSECS" -o "$OUT/cpu.pb.gz"
# instantaneous captures while still under load
curl -s "http://127.0.0.1:$PPROF/debug/pprof/block"            -o "$OUT/block.pb.gz"
curl -s "http://127.0.0.1:$PPROF/debug/pprof/mutex"            -o "$OUT/mutex.pb.gz"
curl -s "http://127.0.0.1:$PPROF/debug/pprof/allocs"           -o "$OUT/allocs.pb.gz"
curl -s "http://127.0.0.1:$PPROF/debug/pprof/goroutine?debug=1" -o "$OUT/goroutine.txt"
curl -s "http://127.0.0.1:$PPROF/debug/pprof/heap?debug=1"      -o "$OUT/memstats.txt"
wait "$WRK" 2>/dev/null
# Wait only on mpstat — a bare `wait` would also block on the service process,
# which is a server that never exits.
[[ -n "$MPSTAT" ]] && wait "$MPSTAT" 2>/dev/null || true

# ── analyze ──────────────────────────────────────────────────────────────────
BIN="$OUT/bal-debug"
PP(){ go tool pprof "$@" 2>/dev/null; }
DIGEST="$OUT/DIGEST.txt"
{
  echo "################ NUTCRACKER PROFILE DIGEST ################"
  echo "commit $(git rev-parse --short HEAD 2>/dev/null)  conns=$CONNS dur=${DURATION}s cpu=${CPUSECS}s  endpoint=$URLPATH"
  echo
  echo "==== wrk ===="; cat "$OUT/wrk.txt"
  echo
  echo "==== GOMAXPROCS / GC ===="
  awk '/^gc [0-9]/{ if(match($0,/[0-9]+ P$/)) p=substr($0,RSTART,RLENGTH); n++ } END{ printf "GOMAXPROCS(P)=%s   GC cycles logged=%d\n", p, n }' "$OUT/gctrace.log"
  echo "goroutines: $(awk 'NR==1{print $1" "$2}' "$OUT/goroutine.txt" 2>/dev/null)"
  grep -E "^# (Mallocs|TotalAlloc|NumGC|GCCPUFraction) " "$OUT/memstats.txt" 2>/dev/null
  echo
  if [[ -f "$OUT/mpstat.txt" ]]; then
    echo "==== per-core CPU (mpstat avg) ===="
    awk '/Average:/ && ($2 ~ /^[0-9]+$/ || $2=="all"){print}' "$OUT/mpstat.txt" | head -8
    echo
  else
    echo "==== per-core CPU: mpstat not installed (sudo yum install -y sysstat) ===="; echo
  fi
  echo "==== CPU (top 25, cumulative) ===="; PP -top -cum -nodecount=25 "$BIN" "$OUT/cpu.pb.gz" | sed -n '1,32p'
  echo
  echo "==== MUTEX contention (top 20 by delay) ===="; PP -top -sample_index=delay -nodecount=20 "$BIN" "$OUT/mutex.pb.gz" | sed -n '1,27p'
  echo
  echo "==== BLOCK (top 20 by delay) ===="; PP -top -sample_index=delay -nodecount=20 "$BIN" "$OUT/block.pb.gz" | sed -n '1,27p'
  echo
  echo "==== ALLOCS (top 15 by bytes) ===="; PP -top -sample_index=alloc_space -nodecount=15 "$BIN" "$OUT/allocs.pb.gz" | sed -n '1,22p'
  echo "##########################################################"
} > "$DIGEST" 2>&1

say "DONE"
echo "Raw profiles + digest in: $OUT/"
echo "Paste this back to me:  cat $DIGEST"
echo
cat "$DIGEST"
