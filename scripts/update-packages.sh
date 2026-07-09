#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

fuser -k 34872/tcp 2>/dev/null || true
wally install
rojo sourcemap default.project.json --output sourcemap.json
wally-package-types --sourcemap sourcemap.json Packages/
