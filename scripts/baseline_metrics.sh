#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "${REPO_ROOT}"

print_heading() {
    printf '\n## %s\n' "$1"
}

collect_top_lines() {
    local label="$1"
    local dir="$2"
    local limit="$3"
    python3 - <<'PY' "${dir}" "${limit}" "${label}"
import pathlib
import sys

target = pathlib.Path(sys.argv[1])
limit = int(sys.argv[2])
label = sys.argv[3]

files = sorted(target.rglob("*.swift"))
counts = []
for path in files:
    try:
        with path.open("r", encoding="utf-8") as handle:
            counts.append((sum(1 for _ in handle), path))
    except UnicodeDecodeError:
        continue

counts.sort(reverse=True)
print(f"{label}")
for lines, path in counts[:limit]:
    print(f"{lines}\t{path}")
PY
}

print_heading "主要Storeファイル上位行数"
collect_top_lines "Stores" "Sources/Stores" 10

print_heading "主要Serviceファイル上位行数"
collect_top_lines "Services" "Sources/Services" 10

print_heading "FetchDescriptor出現数"
total=$(rg -o "FetchDescriptor" Sources Tests | wc -l | tr -d ' ')
in_stores=$(rg -o "FetchDescriptor" Sources/Stores | wc -l | tr -d ' ')
in_services=$(rg -o "FetchDescriptor" Sources/Services | wc -l | tr -d ' ')
in_tests=$(rg -o "FetchDescriptor" Tests | wc -l | tr -d ' ')
printf 'total:%s stores:%s services:%s tests:%s\n' "${total}" "${in_stores}" "${in_services}" "${in_tests}"

print_heading "CategoryHierarchyGrouping利用箇所"
rg -n "CategoryHierarchyGrouping" Sources Tests

print_heading "更新日時"
date -u +"%Y-%m-%dT%H:%M:%SZ"
