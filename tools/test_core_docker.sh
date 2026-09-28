#!/usr/bin/env bash
# Build and test WhydunitCore in the official Swift Linux image (works from Windows via Docker Desktop).
# Usage (Git Bash): tools/test_core_docker.sh
set -euo pipefail
cd "$(dirname "$0")/.."
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd -W 2>/dev/null || pwd):/src:ro" swift:6.2 bash -c '
  mkdir -p /work && cp -r /src/Package.swift /src/Sources /src/Tests /work/ &&
  cd /work && swift build --target WhydunitCore && swift test --filter WhydunitCoreTests'
