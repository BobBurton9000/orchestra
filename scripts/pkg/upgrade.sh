#!/bin/bash

set -euo pipefail

upgrade_one() {
  local pkg_name="$1"

  if ! lock_is_installed "$pkg_name"; then
    log_warn "Package '$pkg_name' is not installed. Skipping."
    return 1
  fi

  if lock_is_forked "$pkg_name"; then
    log_info "$pkg_name is forked; skipping upgrade."
    return 2
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

  local existing_model=""
  local installed_agent_file="$AGENTS_ORCHESTRA_DIR_ABS/agents/${pkg_name}.agent.md"
  if [ "$pkg_type" = "agent" ] && [ -f "$installed_agent_file" ]; then
    existing_model="$(read_frontmatter_value model "$installed_agent_file" 2>/dev/null || true)"
  fi

  local installed_paths
  installed_paths="$(install_files_for_package "$source" "$source_repo" "$pkg_type" "$pkg_path" "$current_sha" "$pkg_name" "$existing_model" 1)" || {
    log_info "Upgrade cancelled for $pkg_name."
    return 1
  }

  lock_write_entry "$pkg_name" "$source" "$pkg_type" "$current_sha" "$installed_paths"
  log_info "Upgraded $pkg_name @ ${current_sha:0:12}"
}

upgrade_refresh_subscribed_sources() {
  _upgrade_refresh_subscribed_source() {
    local source_name="$1"
    local source_repo="$2"
    local baseline_sha="${3:-}"
    [ -n "$baseline_sha" ] || return 0

    log_info "Refreshing subscribed source '$source_name' ($source_repo)..."
    index_refresh_source "$source_name" "$source_repo" >/dev/null
  }

  yaml_sources_each "$PKG_SOURCES_FILE" _upgrade_refresh_subscribed_source
}

upgrade_install_new_subscribed_packages() {
  local added=0
  local skipped=0

  _upgrade_install_new_from_source() {
    local source_name="$1"
    local source_repo="$2"
    local baseline_sha="${3:-}"
    [ -n "$baseline_sha" ] || return 0

    local current_sha
    current_sha="$(index_get_sha "$source_name")"
    [ "$current_sha" != "$baseline_sha" ] || return 0

    local baseline_file
    baseline_file="$(index_subscription_baseline_file_for "$source_name")"
    if [ ! -f "$baseline_file" ]; then
      log_info "Restoring subscription baseline for '$source_name'..."
      if ! gh_fetch_manifest "$source_repo" "$baseline_sha" > "$baseline_file" || [ ! -s "$baseline_file" ]; then
        rm -f "$baseline_file"
        log_warn "Subscription baseline for '$source_name' could not be restored; skipping automatic additions."
        skipped=$((skipped + 1))
        return 0
      fi
    fi

    local pkg_name pkg_type pkg_path
    while IFS=$'\t' read -r pkg_name pkg_type pkg_path; do
      [ -n "$pkg_name" ] || continue

      if lock_is_installed "$pkg_name"; then
        local locked_source
        locked_source="$(lock_get_source "$pkg_name" 2>/dev/null || true)"
        if [ -n "$locked_source" ] && [ "$locked_source" != "$source_name" ]; then
          log_warn "Skipping new package '$pkg_name' from '$source_name': it is already installed from '$locked_source'."
        fi
        continue
      fi

      if package_install_target_exists "$pkg_type" "$pkg_name"; then
        log_warn "Skipping new package '$pkg_name' from '$source_name': its install target already exists."
        skipped=$((skipped + 1))
        continue
      fi

      log_info "Installing new package '$pkg_name' from subscribed source '$source_name'."
      if install_one_package "${pkg_name}@${source_name}" 0; then
        added=$((added + 1))
      else
        skipped=$((skipped + 1))
      fi
    done < <(index_list_new_packages_in_source "$source_name")
  }

  yaml_sources_each "$PKG_SOURCES_FILE" _upgrade_install_new_from_source
  printf '%s\t%s\n' "$added" "$skipped"
}

upgrade_cmd() {
  local pkg="${1:-}"

  ensure_orchestra_dir
  gh_check_auth
  ensure_pkg_dirs

  if [ -n "$pkg" ]; then
    local rc=0
    upgrade_one "$pkg" || rc=$?
    [ "$rc" -eq 2 ] && return 0
    return "$rc"
  fi

  sources_ensure_file
  upgrade_refresh_subscribed_sources

  local pkgs=()
  _upgrade_collect() { pkgs+=("$1"); }
  if [ -f "$PKG_LOCK_FILE" ]; then
    yaml_lock_each "$PKG_LOCK_FILE" _upgrade_collect
  fi

  local upgraded=0 unchanged=0 skipped=0
  for p in "${pkgs[@]}"; do
    local rc=0
    upgrade_one "$p" >/dev/null || rc=$?
    case "$rc" in
      0)  upgraded=$((upgraded + 1)) ;;
      2)  unchanged=$((unchanged + 1)) ;;
      *)  skipped=$((skipped + 1)) ;;
    esac
  done

  local subscription_counts subscription_added subscription_skipped
  subscription_counts="$(upgrade_install_new_subscribed_packages)"
  IFS=$'\t' read -r subscription_added subscription_skipped <<< "$subscription_counts"

  if [ ${#pkgs[@]} -eq 0 ]; then
    if [ "$subscription_added" -gt 0 ] || [ "$subscription_skipped" -gt 0 ]; then
      log_info "Subscription sync complete: $subscription_added new package(s) added, $subscription_skipped skipped."
    else
      echo "No packages installed."
    fi
    return 0
  fi

  echo ""
  log_info "Upgrade complete: $upgraded upgraded, $unchanged up to date, $skipped skipped."
  if [ "$subscription_added" -gt 0 ] || [ "$subscription_skipped" -gt 0 ]; then
    log_info "Subscription sync complete: $subscription_added new package(s) added, $subscription_skipped skipped."
  fi
}
