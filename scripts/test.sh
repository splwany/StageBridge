#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .build/ModuleCache
xcrun swiftc -parse-as-library -swift-version 5 -sdk "${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}" \
    -module-cache-path "$ROOT_DIR/.build/ModuleCache" \
    Sources/Core/*.swift Sources/Services/ProcessRunner.swift Sources/Services/LegacyMigration.swift Tests/CoreChecks.swift -o .build/CoreChecks
.build/CoreChecks
xcrun swiftc -parse-as-library -swift-version 5 -sdk "${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}" \
    -module-cache-path "$ROOT_DIR/.build/ModuleCache" \
    Sources/Core/*.swift Sources/Services/*.swift Sources/App/Monitor.swift Tests/MonitorChecks.swift -o .build/MonitorChecks
.build/MonitorChecks
