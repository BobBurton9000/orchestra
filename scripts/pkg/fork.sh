#!/bin/bash

set -euo pipefail

fork_cmd() {
  local pkg="${1:-}"
  [ -n "$pkg" ] || die "Usage: orchestra fork <pkg>"

  ensure_orchestra_dir

  if ! lock_is_installed "$pkg"; then
    die "Package '$pkg' is not installed. Run 'orchestra list' to see installed packages."
  fi

  if lock_is_forked "$pkg"; then
    log_info "Package '$pkg' is already forked."
    return 0
  fi

  local source
  source="$(lock_get_source "$pkg")"
  yaml_lock_mark_forked "$PKG_LOCK_FILE" "$pkg"
  log_info "Forked '$pkg' from source '$source'. Future upgrades will leave it unchanged."
}
