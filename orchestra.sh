#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
export ORCHESTRA_PROJECT_ROOT="$PROJECT_ROOT"

PKG_DIR="$SCRIPT_DIR/scripts/pkg"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"
source "$PKG_DIR/pkg-common.sh"
source "$PKG_DIR/yaml-helpers.sh"
source "$PKG_DIR/ghutil.sh"
source "$PKG_DIR/sources.sh"
source "$PKG_DIR/index.sh"
source "$PKG_DIR/install.sh"
source "$PKG_DIR/uninstall.sh"
source "$PKG_DIR/upgrade.sh"
source "$PKG_DIR/list.sh"
source "$PKG_DIR/manifest.sh"

if [ -f "$PKG_DIR/export.sh" ]; then
  source "$PKG_DIR/export.sh"
fi
if [ -f "$PKG_DIR/convert.sh" ]; then
  source "$PKG_DIR/convert.sh"
fi

source "$PKG_DIR/cli.sh"

ORCHESTRA_YES="${ORCHESTRA_YES:-}"
export ORCHESTRA_YES

orchestra_main "$@"