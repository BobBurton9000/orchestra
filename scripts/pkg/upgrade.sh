#!/bin/bash

set -euo pipefail

upgrade_one() {
  local pkg_name="$1"

  if ! lock_is_installed "$pkg_name"; then
    log_warn "Package '$pkg_name' is not installed. Skipping."
    return 1
  fi

  local locked_sha source pkg_type
  locked_sha="$(lock_get_sha "$pkg_name")"
  source="$(lock_get_source "$pkg_name")"
  pkg_type="$(lock_get_type "$pkg_name")"

  local source_repo
  source_repo="$(sources_lookup_repo "$source" || true)"
  [ -n "$source_repo" ] || die "Source '$source' is no longer configured but '$pkg_name' is locked to it. Run 'orchestra source add <owner>/<repo> $source'."

  if ! index_ensure_cached "$source"; then
    log_info "Caching source '$source'..."
    index_refresh_source "$source" "$source_repo" >/dev/null
  fi

  local current_sha
  current_sha="$(index_get_sha "$source")"

  if [ "$current_sha" = "$locked_sha" ]; then
    log_info "$pkg_name is up to date (${locked_sha:0:12})."
    return 2
  fi

  log_info "Upgrading $pkg_name: ${locked_sha:0:12} -> ${current_sha:0:12}"

  local found=""
  found="$(index_find_package "$pkg_name" "$source" || true)"
  [ -n "$found" ] || die "Package '$pkg_name' not found in source '$source' anymore. Source manifest may have changed."

  local _src _repo pkg_path
  IFS=$'\t' read -r _src _repo _type pkg_path <<< "$found"

  local installed_paths
  installed_paths="$(install_files_for_package "$source" "$source_repo" "$pkg_type" "$pkg_path" "$current_sha" "$pkg_name")" || {
    log_info "Upgrade cancelled for $pkg_name."
    return 1
  }

  lock_write_entry "$pkg_name" "$source" "$pkg_type" "$current_sha" "$installed_paths"
  log_info "Upgraded $pkg_name @ ${current_sha:0:12}"
}

upgrade_cmd() {
  local pkg="${1:-}"

  ensure_orchestra_dir
  gh_check_auth
  ensure_pkg_dirs

  if [ -n "$pkg" ]; then
    upgrade_one "$pkg"
    return
  fi

  [ -f "$PKG_LOCK_FILE" ] || {
    echo "No packages installed."
    return 0
  }

  local pkgs=()
  _upgrade_collect() { pkgs+=("$1"); }
  yaml_lock_each "$PKG_LOCK_FILE" _upgrade_collect

  if [ ${#pkgs[@]} -eq 0 ]; then
    echo "No packages installed."
    return 0
  fi

  local upgraded=0 unchanged=0 skipped=0
  for p in "${pkgs[@]}"; do
    local rc=0
    upgrade_one "$p" >/dev/null 2>&1 || rc=$?
    case "$rc" in
      0)  upgraded=$((upgraded + 1)) ;;
      2)  unchanged=$((unchanged + 1)) ;;
      *)  skipped=$((skipped + 1)) ;;
    esac
  done

  echo ""
  log_info "Upgrade complete: $upgraded upgraded, $unchanged up to date, $skipped skipped."
}