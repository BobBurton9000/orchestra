#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PKG_DIR="$SCRIPT_DIR/scripts/pkg"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

source "$SCRIPTS_DIR/common.sh"

if [ -n "${ORCHESTRA_PROJECT_ROOT:-}" ]; then
  requested_root="$ORCHESTRA_PROJECT_ROOT"
  ORCHESTRA_PROJECT_ROOT="$(cd "$requested_root" 2>/dev/null && pwd)" ||
    die "Project root does not exist: $requested_root"
else
  ORCHESTRA_PROJECT_ROOT="$(detect_project_root || pwd)"
fi
export ORCHESTRA_PROJECT_ROOT

source "$PKG_DIR/pkg-common.sh"
source "$PKG_DIR/yaml-helpers.sh"
source "$PKG_DIR/ghutil.sh"
source "$PKG_DIR/sources.sh"
source "$PKG_DIR/index.sh"
source "$PKG_DIR/install.sh"
source "$PKG_DIR/uninstall.sh"
source "$PKG_DIR/fork.sh"
source "$PKG_DIR/push.sh"
source "$PKG_DIR/upgrade.sh"
source "$PKG_DIR/list.sh"
source "$PKG_DIR/status.sh"
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
