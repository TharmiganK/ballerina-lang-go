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

# profile-aws.sh — one-shot profiler for a Nutcracker HTTP service.
# Run from the repository root:   bash performance/scripts/profile-aws.sh
# It builds a debug binary, loads the service with wrk, captures CPU/heap/
# block/mutex/goroutine profiles, and writes a single digest to paste back.
#
# Optional env overrides:
#   MODE=cpu|all  SCENARIO=hello|passthrough  PAYLOAD=1KB|10KB|50KB
#   CONNS=200 DURATION=50 CPUSECS=30 PORT=9090 PPROF=6060
# e.g.  MODE=cpu SCENARIO=passthrough PAYLOAD=1KB bash performance/scripts/profile-aws.sh
# passthrough also starts the Netty echo backend on :8688 (builds it if needed).

set -uo pipefail

# MODE=all  → CPU + heap + block + mutex profiles (block/mutex show contention).
# MODE=cpu  → CPU-only: block/mutex profiling is disabled so it neither adds
#             overhead nor distorts the CPU profile; the digest reports flat
#             (self) CPU time — the trustworthy view of where cycles actually go.
MODE="${MODE:-all}"
# SCENARIO=hello       → GET /hello (default).
# SCENARIO=passthrough → POST a PAYLOAD to /passthrough, which the service
#                        forwards to a Netty echo backend on :8688 — exercises
#                        the http:Client path. PAYLOAD names a performance/payloads/ file.
SCENARIO="${SCENARIO:-hello}"
PAYLOAD="${PAYLOAD:-1KB}"
CONNS="${CONNS:-200}"
DURATION="${DURATION:-50}"
CPUSECS="${CPUSECS:-30}"
PORT="${PORT:-9090}"
PPROF="${PPROF:-6060}"
OUT="perf-profile-$(date +%Y%m%d-%H%M%S)"
PROF_SRC="cli/cmd/prof_debug.go"
BACKEND_JAR="performance/backend/target/perf-backend.jar"
BACKEND_PORT=8688
PAYLOAD_FILE="performance/payloads/${PAYLOAD}.txt"
LUA="performance/scripts/post_payload.lua"

case "$SCENARIO" in
  hello)       BAL="performance/services/ballerina/hello.bal";       SVCPATH="/hello" ;;
  passthrough) BAL="performance/services/ballerina/passthrough.bal"; SVCPATH="/passthrough" ;;
  *) echo "ERROR: SCENARIO must be 'hello' or 'passthrough'"; exit 1 ;;
esac

say(){ printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

# ── sanity ───────────────────────────────────────────────────────────────────
[[ -f go.mod && -f "$PROF_SRC" && -f "$BAL" ]] || {
  echo "ERROR: run this from the repository root (go.mod, $PROF_SRC, $BAL must exist)"; exit 1; }
for t in go wrk curl awk; do command -v "$t" >/dev/null || { echo "ERROR: '$t' not found"; exit 1; }; done
if [[ "$SCENARIO" == passthrough ]]; then
  command -v java >/dev/null || { echo "ERROR: 'java' needed for the passthrough backend"; exit 1; }
  [[ -f "$LUA" ]]          || { echo "ERROR: missing $LUA"; exit 1; }
  [[ -f "$PAYLOAD_FILE" ]] || { echo "ERROR: missing payload $PAYLOAD_FILE (set PAYLOAD=1KB|10KB|50KB|…)"; exit 1; }
  if [[ ! -f "$BACKEND_JAR" ]]; then
    echo "Building Netty echo backend (mvn)…"
    (cd performance/backend && mvn -q -DskipTests package) || { echo "ERROR: backend build failed"; exit 1; }
  fi
fi

mkdir -p "$OUT"
echo "commit: $(git rev-parse --short HEAD 2>/dev/null || echo '?')  |  output dir: $OUT"

# ── set block/mutex profiling to match MODE (temporary source patch) ─────────
# MODE=all needs it present (for the block/mutex profiles); MODE=cpu needs it
# absent (so it doesn't add overhead or distort the CPU profile). Either way the
# source is restored afterwards.
PATCHED=0
has_bm(){ grep -q "SetMutexProfileFraction" "$PROF_SRC"; }
if [[ "$MODE" == cpu ]] && has_bm; then
  say "Disabling block/mutex profiling in $PROF_SRC for a clean CPU profile (temporary)"
  cp "$PROF_SRC" "$OUT/prof_debug.go.bak"
  perl -0pi -e 's/\n\truntime\.SetBlockProfileRate\(\d+\)\n\truntime\.SetMutexProfileFraction\(\d+\)\n//' "$PROF_SRC"
  has_bm || PATCHED=1
elif [[ "$MODE" != cpu ]] && ! has_bm; then
  say "Enabling block/mutex profiling in $PROF_SRC (temporary)"
  cp "$PROF_SRC" "$OUT/prof_debug.go.bak"
  perl -0pi -e 's/(\n\tif !p\.enabled \{\n\t\treturn nil\n\t\}\n)/$1\n\truntime.SetBlockProfileRate(10000)\n\truntime.SetMutexProfileFraction(10)\n/' "$PROF_SRC"
  if has_bm; then PATCHED=1; else
    echo "WARN: could not auto-patch; block/mutex profiles may be empty"; cp "$OUT/prof_debug.go.bak" "$PROF_SRC"; fi
fi
restore(){ [[ "$PATCHED" == 1 ]] && cp "$OUT/prof_debug.go.bak" "$PROF_SRC" && echo "restored $PROF_SRC"; }

# ── build ────────────────────────────────────────────────────────────────────
say "Building debug binary"
go build -tags debug -o "$OUT/bal-debug" ./cli/cmd || { restore; exit 1; }

# ── free ports ────────────────────────────────────────────────────────────────
FREE_PORTS=("$PORT" "$PPROF")
[[ "$SCENARIO" == passthrough ]] && FREE_PORTS+=("$BACKEND_PORT")
for p in "${FREE_PORTS[@]}"; do
  pids=$(lsof -tiTCP:"$p" -sTCP:LISTEN 2>/dev/null); [[ -n "$pids" ]] && kill -9 $pids 2>/dev/null; done
sleep 0.5

# ── start the Netty echo backend (passthrough only) ──────────────────────────
BACKEND_PID=""
if [[ "$SCENARIO" == passthrough ]]; then
  say "Starting Netty echo backend on :$BACKEND_PORT"
  java -jar "$BACKEND_JAR" --ssl false --http2 false >"$OUT/backend.log" 2>&1 &
  BACKEND_PID=$!
  for i in $(seq 1 300); do (exec 3<>"/dev/tcp/127.0.0.1/$BACKEND_PORT") 2>/dev/null && break; sleep 0.1; done
fi

say "Starting service (GODEBUG=gctrace=1)"
GODEBUG=gctrace=1 "$OUT/bal-debug" run --prof --prof-addr ":$PPROF" "$BAL" \
  >"$OUT/service.out" 2>"$OUT/gctrace.log" &
SVC=$!
trap 'kill -9 $SVC 2>/dev/null; [[ -n "$BACKEND_PID" ]] && kill -9 $BACKEND_PID 2>/dev/null; restore' EXIT

# wait until the service answers (GET for hello, POST the payload for passthrough)
URL="http://127.0.0.1:$PORT$SVCPATH"
ready=0
for i in $(seq 1 300); do
  if [[ "$SCENARIO" == hello ]]; then
    curl -s "$URL" 2>/dev/null | grep -q Hello && { ready=1; break; }
  else
    code=$(curl -s -o /dev/null -w '%{http_code}' -X POST --data-binary @"$PAYLOAD_FILE" \
             -H 'Content-Type: text/plain' "$URL" 2>/dev/null)
    [[ "$code" == 200 ]] && { ready=1; break; }
  fi
  sleep 0.1
done
[[ "$ready" == 1 ]] || {
  echo "ERROR: service not ready on :$PORT (scenario=$SCENARIO)"
  tail -20 "$OUT/gctrace.log"; [[ -f "$OUT/backend.log" ]] && tail -5 "$OUT/backend.log"; exit 1; }
echo "service up; scenario=$SCENARIO endpoint=$URL"
curl -s "http://127.0.0.1:$PPROF/debug/pprof/" -o /dev/null -w "pprof endpoint http=%{http_code}\n"

# ── load + capture ───────────────────────────────────────────────────────────
say "Load: wrk -t4 -c$CONNS -d${DURATION}s scenario=$SCENARIO (capturing during it)"
if [[ "$SCENARIO" == hello ]]; then
  wrk -t4 -c"$CONNS" -d"${DURATION}s" --latency "$URL" >"$OUT/wrk.txt" 2>&1 &
else
  PAYLOAD_FILE="$PAYLOAD_FILE" wrk -t4 -c"$CONNS" -d"${DURATION}s" --latency -s "$LUA" "$URL" >"$OUT/wrk.txt" 2>&1 &
fi
WRK=$!
sleep 5
# per-core OS view (best effort)
MPSTAT=""
if command -v mpstat >/dev/null; then mpstat -P ALL 1 "$CPUSECS" >"$OUT/mpstat.txt" 2>&1 & MPSTAT=$!; fi
# CPU profile blocks for CPUSECS
curl -s "http://127.0.0.1:$PPROF/debug/pprof/profile?seconds=$CPUSECS" -o "$OUT/cpu.pb.gz"
# instantaneous captures while still under load (block/mutex only in full mode)
if [[ "$MODE" != cpu ]]; then
  curl -s "http://127.0.0.1:$PPROF/debug/pprof/block"          -o "$OUT/block.pb.gz"
  curl -s "http://127.0.0.1:$PPROF/debug/pprof/mutex"          -o "$OUT/mutex.pb.gz"
fi
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
  echo "commit $(git rev-parse --short HEAD 2>/dev/null)  scenario=$SCENARIO payload=$([[ $SCENARIO == passthrough ]] && echo $PAYLOAD || echo -)  conns=$CONNS dur=${DURATION}s cpu=${CPUSECS}s  endpoint=$SVCPATH"
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
  echo "==== CPU FLAT self-time (top 30) — where cycles actually go ===="
  PP -top -flat -nodecount=30 "$BIN" "$OUT/cpu.pb.gz" | sed -n '1,37p'
  echo
  echo "==== CPU (top 25, cumulative) ===="; PP -top -cum -nodecount=25 "$BIN" "$OUT/cpu.pb.gz" | sed -n '1,32p'
  if [[ "$MODE" != cpu ]]; then
    echo
    echo "==== MUTEX contention (top 20 by delay) ===="; PP -top -sample_index=delay -nodecount=20 "$BIN" "$OUT/mutex.pb.gz" | sed -n '1,27p'
    echo
    echo "==== BLOCK (top 20 by delay) ===="; PP -top -sample_index=delay -nodecount=20 "$BIN" "$OUT/block.pb.gz" | sed -n '1,27p'
  fi
  echo
  echo "==== ALLOCS (top 15 by bytes) ===="; PP -top -sample_index=alloc_space -nodecount=15 "$BIN" "$OUT/allocs.pb.gz" | sed -n '1,22p'
  echo "##########################################################"
} > "$DIGEST" 2>&1

say "DONE"
echo "Raw profiles + digest in: $OUT/"
echo "Paste this back to me:  cat $DIGEST"
echo
cat "$DIGEST"
