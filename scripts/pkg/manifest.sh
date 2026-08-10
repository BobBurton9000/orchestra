#!/bin/bash

set -euo pipefail

MANIFEST_STANDALONE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/orchestra-manifest.sh"

manifest_generate() {
  "$MANIFEST_STANDALONE" "$@"
}
