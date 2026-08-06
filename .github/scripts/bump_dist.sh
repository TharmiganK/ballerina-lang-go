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
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

module_prefix="github.com/ballerina-nutcracker/ballerina"
version_files=(
    go.work
    interpsrc.go
    cli/internal/nativerunner/local_executor.go
)

version="${1:-}"
if [[ -z "$version" ]]; then
    echo "usage: make bumpDist VERSION=vMAJOR.MINOR.PATCH[-PRERELEASE]" >&2
    exit 1
fi
if [[ ! "$version" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$ ]]; then
    echo "invalid distribution version: $version" >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

modules_file="$(mktemp)"
trap 'rm -f "$modules_file"' EXIT

go list -m -f '{{if .Main}}{{.Path}}{{"\t"}}{{.Dir}}{{end}}' all |
    awk -F '\t' -v prefix="$module_prefix" '$1 == prefix || index($1, prefix "/") == 1' > "$modules_file"

if [[ ! -s "$modules_file" ]]; then
    echo "no distribution modules found in the Go workspace" >&2
    exit 1
fi

internal_requirements() {
    awk -v prefix="$module_prefix" '
        ($1 == prefix || index($1, prefix "/") == 1) && $2 ~ /^v[0-9]/ { print $1, $2 }
        $1 == "require" && ($2 == prefix || index($2, prefix "/") == 1) && $3 ~ /^v[0-9]/ { print $2, $3 }
    ' "$1"
}

existing_versions="$({
    while IFS=$'\t' read -r _ module_dir; do
        internal_requirements "$module_dir/go.mod" | awk '{ print $2 }'
    done < "$modules_file"
    for file in "${version_files[@]}"; do
        grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?' "$file"
    done
} | sort -u)"

version_count="$(printf '%s\n' "$existing_versions" | sed '/^$/d' | wc -l | tr -d ' ')"
if [[ "$version_count" -ne 1 ]]; then
    echo "internal module references do not use one shared version:" >&2
    printf '%s\n' "$existing_versions" >&2
    exit 1
fi

old_version="$(printf '%s\n' "$existing_versions" | sed '/^$/d')"
if [[ "$old_version" != "$version" ]]; then
    while IFS=$'\t' read -r _ module_dir; do
        dependencies="$(internal_requirements "$module_dir/go.mod")"
        while read -r dependency _; do
            [[ -z "$dependency" ]] && continue
            go mod edit "-require=$dependency@$version" "$module_dir/go.mod"
        done < <(printf '%s\n' "$dependencies")
    done < "$modules_file"

    python3 - "$old_version" "$version" "${version_files[@]}" <<'PY'
from pathlib import Path
import sys

old_version, new_version, *files = sys.argv[1:]
for name in files:
    path = Path(name)
    content = path.read_text()
    updated = content.replace(old_version, new_version)
    if updated == content:
        raise SystemExit(f"{name}: did not contain {old_version}")
    path.write_text(updated)
PY
fi

failed=false
while IFS=$'\t' read -r _ module_dir; do
    while read -r dependency dependency_version; do
        [[ -z "$dependency" ]] && continue
        if [[ "$dependency_version" != "$version" ]]; then
            echo "$module_dir/go.mod: $dependency is $dependency_version, expected $version" >&2
            failed=true
        fi
    done < <(internal_requirements "$module_dir/go.mod")
done < "$modules_file"
for file in "${version_files[@]}"; do
    while read -r found_version; do
        [[ -z "$found_version" ]] && continue
        if [[ "$found_version" != "$version" ]]; then
            echo "$file: found $found_version, expected $version" >&2
            failed=true
        fi
    done < <(grep -Eo 'v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?' "$file" | sort -u)
done
if [[ "$failed" == true ]]; then
    exit 1
fi

if [[ "$old_version" == "$version" ]]; then
    echo "Distribution module references already use $version"
else
    echo "Updated distribution module references from $old_version to $version"
fi
make build
