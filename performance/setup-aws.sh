#!/usr/bin/env bash

# setup-aws.sh — install every prerequisite of performance/run.sh on an
# Amazon Linux 2023 instance. Run once as ec2-user:
#
#   ./performance/setup-aws.sh          # everything (incl. GraalVM)
#   SKIP_GRAALVM=1 ./performance/setup-aws.sh
#
# After it finishes, open a new shell (or `source /etc/profile.d/perf-bench.sh`)
# and build this repo's bal:  cd <repo> && go build -o bal ./cli/cmd

set -euo pipefail

ARCH="$(uname -m)"                       # x86_64 | aarch64
case "$ARCH" in
    x86_64)  GOARCH=amd64; GRAAL_ARCH=x64 ;;
    aarch64) GOARCH=arm64; GRAAL_ARCH=aarch64 ;;
    *) echo "Unsupported arch: $ARCH" >&2; exit 1 ;;
esac

# Pin the jBallerina (Swan Lake) version here.
BAL_VERSION="${BAL_VERSION:-2201.13.4}"

echo "==> Base tooling (gcc, make, git, perl, lsof, ...)"
sudo dnf -y install gcc make git perl lsof procps-ng unzip tar gzip \
    openssl-devel zlib-devel python3 python3-pip nodejs npm

echo "==> wrk (built from source; no AL2023 package)"
if ! command -v wrk >/dev/null; then
    git clone --depth 1 https://github.com/wg/wrk /tmp/wrk
    make -C /tmp/wrk -j"$(nproc)"
    sudo install -m 0755 /tmp/wrk/wrk /usr/local/bin/wrk
    rm -rf /tmp/wrk
fi

echo "==> Go (latest stable; repo needs 1.26+)"
GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)"   # e.g. go1.26.0
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q "$GO_VERSION"; then
    curl -fsSL -o /tmp/go.tgz "https://go.dev/dl/${GO_VERSION}.linux-${GOARCH}.tar.gz"
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tgz
    rm -f /tmp/go.tgz
fi

echo "==> Java 21 (Corretto) + Maven"
sudo dnf -y install java-21-amazon-corretto-devel maven
# AL2023's maven package may drag in Corretto 17 as a dependency; force 21.
JAVA21_HOME="$(dirname "$(dirname "$(readlink -f /usr/lib/jvm/java-21-amazon-corretto/bin/java)")")"

echo "==> jBallerina Swan Lake $BAL_VERSION"
if ! command -v bal >/dev/null; then
    if [[ "$ARCH" == "x86_64" ]]; then
        curl -fsSL -o /tmp/ballerina.rpm \
            "https://dist.ballerina.io/downloads/${BAL_VERSION}/ballerina-${BAL_VERSION}-swan-lake-linux-x64.rpm"
        sudo dnf -y install /tmp/ballerina.rpm
        rm -f /tmp/ballerina.rpm
    else
        echo "  WARNING: no official Ballerina build for aarch64 — the swanlake" >&2
        echo "  and swanlake-graalvm runtimes will be unavailable on this instance." >&2
    fi
fi

if [[ -z "${SKIP_GRAALVM:-}" ]]; then
    echo "==> GraalVM JDK 21 (native-image, for the two *-graalvm runtimes)"
    if ! command -v native-image >/dev/null && [[ ! -d /opt/graalvm ]]; then
        curl -fsSL -o /tmp/graalvm.tgz \
            "https://download.oracle.com/graalvm/21/latest/graalvm-jdk-21_linux-${GRAAL_ARCH}_bin.tar.gz"
        sudo mkdir -p /opt/graalvm
        sudo tar -C /opt/graalvm --strip-components=1 -xzf /tmp/graalvm.tgz
        rm -f /tmp/graalvm.tgz
    fi
else
    echo "==> Skipping GraalVM (SKIP_GRAALVM set)"
fi

echo "==> Python deps for python-flask"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
pip3 install --user -r "$SCRIPT_DIR/services/python-flask/requirements.txt"

echo "==> Environment (/etc/profile.d/perf-bench.sh)"
sudo tee /etc/profile.d/perf-bench.sh >/dev/null <<EOF
export JAVA_HOME=$JAVA21_HOME
export GRAALVM_HOME=/opt/graalvm
# Corretto java first; GraalVM appended only for native-image.
export PATH=\$JAVA_HOME/bin:/usr/local/go/bin:\$HOME/go/bin:\$PATH:/opt/graalvm/bin
EOF

echo "==> Raising open-file limit for benchmark load (soft nofile 65535)"
sudo tee /etc/security/limits.d/99-perf-bench.conf >/dev/null <<'EOF'
* soft nofile 65535
* hard nofile 65535
EOF

echo ""
echo "Done. Now:"
echo "  1. Re-login (or: source /etc/profile.d/perf-bench.sh) so PATH/limits apply."
echo "  2. Build Nutcracker's bal:   cd <repo-root> && go build -o bal ./cli/cmd"
echo "  3. Verify:                   wrk -v; lsof -v; go version; bal version;"
echo "                               java -version; mvn -v; node -v; native-image --version"
echo "  4. Run:                      ./performance/run.sh"
