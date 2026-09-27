#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .build/ModuleCache
xcrun swiftc -parse-as-library -sdk "${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}" \
    -module-cache-path "$ROOT_DIR/.build/ModuleCache" \
    Sources/Core/ConnectionPolicy.swift Tests/CoreChecks.swift -o .build/CoreChecks
.build/CoreChecks
