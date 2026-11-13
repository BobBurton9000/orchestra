#!/bin/bash

set -euo pipefail

upgrade_path_is_safe() {
  local path="$1"
  case "$path" in
    agents/*|prompts/*|skills/*) ;;
    *) return 1 ;;
  esac
  case "$path" in
    /*|*//*|*/|*"/../"*|../*|*/..|..|*"/./"*|./*|*/.) return 1 ;;
  esac
  [[ "$path" != *$'\n'* && "$path" != *$'\t'* ]]
}

upgrade_choose_stale_action() {
  local path="$1"
  local result_name="$2"
  local -n result_ref="$result_name"

  if [ -n "${ORCHESTRA_YES:-}" ]; then
    result_ref="remove"
    log_info "Automatically removing stale file '$path' (ORCHESTRA_YES=1)."
    return 0
  fi

  if [ ! -t 0 ]; then
    log_warn "Cannot resolve stale file '$path' without a TTY. Rerun interactively or set ORCHESTRA_YES=1 to remove stale files."
    return 2
  fi

  local answer
  while :; do
    read -rp "Stale file '$path': [r]emove, [k]eep, or [c]ancel this package upgrade? [k] " answer || answer=""
    case "${answer,,}" in
      ""|k|keep)
        result_ref="keep"
        return 0
        ;;
      r|remove)
        result_ref="remove"
        return 0
        ;;
      c|cancel)
        result_ref="cancel"
        return 0
        ;;
      *)
        log_warn "Choose remove (r), keep (k), or cancel (c)."
        ;;
    esac
  done
}

upgrade_record_missing_parent_dirs() {
  local target="$1"
  local dirs_name="$2"
  local seen_name="$3"
  local -n dirs_ref="$dirs_name"
  local -n seen_ref="$seen_name"

  local dir
  dir="$(dirname "$target")"
  while [[ "$dir" == "$AGENTS_ORCHESTRA_DIR_ABS/"* ]]; do
    if [ ! -d "$dir" ] && [ -z "${seen_ref[$dir]+set}" ]; then
      dirs_ref+=("$dir")
      seen_ref["$dir"]=1
    fi
    dir="$(dirname "$dir")"
  done
}

upgrade_prune_empty_package_dirs() {
  local path="$1"
  local package_root="$2"
  local removed_name="$3"
  local -n removed_ref="$removed_name"

  local dir="$AGENTS_ORCHESTRA_DIR_ABS/$path"
  dir="$(dirname "$dir")"
  while [[ "$dir" == "$package_root" || "$dir" == "$package_root/"* ]]; do
    [ -d "$dir" ] || break
    if rmdir "$dir" 2>/dev/null; then
      removed_ref+=("$dir")
    elif [ -z "$(find "$dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
      log_err "Could not remove empty package directory '$dir'."
      return 1
    else
      break
    fi
    [ "$dir" = "$package_root" ] && break
    dir="$(dirname "$dir")"
  done
}

upgrade_restore_transaction() {
  local backup_root="$1"
  local affected_name="$2"
  local removed_dirs_name="$3"
  local created_dirs_name="$4"
  local -n affected_ref="$affected_name"
  local -n removed_dirs_ref="$removed_dirs_name"
  local -n created_dirs_ref="$created_dirs_name"

  local failures=0 dir i path target backup
  for dir in "${removed_dirs_ref[@]}"; do
    if ! mkdir -p "$dir"; then
      log_err "Rollback could not restore directory '$dir'."
      failures=1
    fi
  done

  for ((i=${#affected_ref[@]} - 1; i >= 0; i--)); do
    path="${affected_ref[$i]}"
    target="$AGENTS_ORCHESTRA_DIR_ABS/$path"
    backup="$backup_root/$path"

    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ -d "$target" ] && [ ! -L "$target" ]; then
        log_err "Rollback could not replace directory at '$target'."
        failures=1
        continue
      fi
      if ! rm -f "$target"; then
        log_err "Rollback could not remove changed file '$target'."
        failures=1
        continue
      fi
    fi

    if [ -e "$backup" ] || [ -L "$backup" ]; then
      if ! mkdir -p "$(dirname "$target")" || ! cp -a "$backup" "$target"; then
        log_err "Rollback could not restore file '$target'."
        failures=1
      fi
    fi
  done

  for dir in "${created_dirs_ref[@]}"; do
    rmdir "$dir" 2>/dev/null || true
  done

  return "$failures"
}

upgrade_write_lock_candidate() {
  local candidate="$1"
  local pkg_name="$2"
  local source="$3"
  local pkg_type="$4"
  local sha="$5"
  local source_repo="$6"
  local pkg_path="$7"
  shift 7
  local paths=("$@")

  local original_lock_file="$PKG_LOCK_FILE"
  local rc=0
  PKG_LOCK_FILE="$candidate"
  lock_write_entry "$pkg_name" "$source" "$pkg_type" "$sha" "$source_repo" "$pkg_path" "${paths[@]}" || rc=$?
  PKG_LOCK_FILE="$original_lock_file"
  return "$rc"
}

upgrade_remove_lock_candidate() {
  local candidate="$1"
  local pkg_name="$2"
  local original_lock_file="$PKG_LOCK_FILE"
  local rc=0
  PKG_LOCK_FILE="$candidate"
  lock_remove_entry "$pkg_name" || rc=$?
  PKG_LOCK_FILE="$original_lock_file"
  return "$rc"
}

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

  case "$pkg_name" in
    ""|*/*|.|..) log_err "Unsafe package name in lockfile: '$pkg_name'."; return 1 ;;
  esac

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

  local found="" package_removed=0 pkg_path=""
  found="$(index_find_package "$pkg_name" "$source" || true)"
  if [ -z "$found" ]; then
    local source_manifest
    source_manifest="$(index_cache_dir_for "$source")/manifest.yaml"
    if ! yaml_manifest_is_valid "$source_manifest"; then
      log_err "Cannot determine whether '$pkg_name' was removed: cached manifest for source '$source' is invalid."
      return 1
    fi
    package_removed=1
    log_info "Package '$pkg_name' is no longer listed in source '$source'; resolving its installed files."
  else
    local _src _repo _type
    IFS=$'\t' read -r _src _repo _type pkg_path <<< "$found"
  fi

  local existing_model=""
  local installed_agent_file="$AGENTS_ORCHESTRA_DIR_ABS/agents/${pkg_name}.agent.md"
  if [ "$pkg_type" = "agent" ] && [ -f "$installed_agent_file" ]; then
    existing_model="$(read_frontmatter_value model "$installed_agent_file" 2>/dev/null || true)"
  fi

  local old_paths=() old_path
  while IFS= read -r old_path; do
    [ -n "$old_path" ] || continue
    if ! upgrade_path_is_safe "$old_path"; then
      log_err "Unsafe installed path in lockfile for '$pkg_name': '$old_path'."
      return 1
    fi
    old_paths+=("$old_path")
  done < <(yaml_lock_paths_lines "$PKG_LOCK_FILE" "$pkg_name")

  local transaction_parent="$ORCHESTRA_PROJECT_ROOT/$ORCHESTRA_DIR"
  local transaction_dir
  transaction_dir="$(mktemp -d "$transaction_parent/upgrade.XXXXXX")" || {
    log_err "Could not create a temporary upgrade workspace for '$pkg_name'."
    return 1
  }
  local stage_root="$transaction_dir/stage"
  mkdir -p "$stage_root" || {
    log_err "Could not prepare a temporary upgrade workspace for '$pkg_name'."
    rm -rf "$transaction_dir"
    return 1
  }

  local installed_paths_output="" installed_path
  local installed_paths=()
  declare -A new_paths_map=()
  if [ "$package_removed" -eq 0 ]; then
    if ! installed_paths_output="$(install_files_for_package "$source" "$source_repo" "$pkg_type" "$pkg_path" "$current_sha" "$pkg_name" "$existing_model" 1 "$stage_root")"; then
      log_err "Could not stage the updated files for '$pkg_name'; the installed package was not changed."
      rm -rf "$transaction_dir"
      return 1
    fi

    while IFS= read -r installed_path; do
      [ -n "$installed_path" ] || continue
      if ! upgrade_path_is_safe "$installed_path"; then
        log_err "The source produced an unsafe installed path for '$pkg_name': '$installed_path'."
        rm -rf "$transaction_dir"
        return 1
      fi
      if [ -z "${new_paths_map[$installed_path]+set}" ]; then
        installed_paths+=("$installed_path")
        new_paths_map["$installed_path"]=1
      fi
    done <<< "$installed_paths_output"
    if [ ${#installed_paths[@]} -eq 0 ]; then
      log_err "The updated package '$pkg_name' contains no installable files."
      rm -rf "$transaction_dir"
      return 1
    fi
  fi

  local stale_paths=() target
  for old_path in "${old_paths[@]}"; do
    [ -z "${new_paths_map[$old_path]+set}" ] || continue
    target="$AGENTS_ORCHESTRA_DIR_ABS/$old_path"
    if [ -f "$target" ] || [ -L "$target" ]; then
      stale_paths+=("$old_path")
    elif [ -e "$target" ]; then
      log_err "Stale package path '$target' is not a file or symlink; refusing to remove it."
      rm -rf "$transaction_dir"
      return 1
    fi
  done

  local stale_path action prompt_rc
  declare -A stale_actions=()
  for stale_path in "${stale_paths[@]}"; do
    action=""
    if upgrade_choose_stale_action "$stale_path" action; then
      if [ "$action" = "cancel" ]; then
        log_info "Upgrade cancelled for $pkg_name; its installed files and lock entry were left unchanged."
        rm -rf "$transaction_dir"
        return 1
      fi
      stale_actions["$stale_path"]="$action"
    else
      prompt_rc=$?
      [ "$prompt_rc" -eq 2 ] || log_info "Upgrade cancelled for $pkg_name."
      rm -rf "$transaction_dir"
      return 1
    fi
  done

  local remove_paths=()
  for stale_path in "${stale_paths[@]}"; do
    [ "${stale_actions[$stale_path]}" = "remove" ] && remove_paths+=("$stale_path")
  done

  local package_root=""
  case "$pkg_type" in
    skill) package_root="$AGENTS_ORCHESTRA_DIR_ABS/skills/$pkg_name" ;;
    prompt-dir) package_root="$AGENTS_ORCHESTRA_DIR_ABS/prompts/$pkg_name" ;;
  esac

  local affected_paths=() path
  declare -A affected_map=()
  for path in "${installed_paths[@]}" "${remove_paths[@]}"; do
    [ -n "$path" ] || continue
    if [ -z "${affected_map[$path]+set}" ]; then
      affected_paths+=("$path")
      affected_map["$path"]=1
    fi
  done

  for path in "${installed_paths[@]}"; do
    target="$AGENTS_ORCHESTRA_DIR_ABS/$path"
    if [ -d "$target" ] && [ ! -L "$target" ]; then
      log_err "Cannot install '$pkg_name': a directory already exists at file path '$target'."
      rm -rf "$transaction_dir"
      return 1
    fi
  done

  local lock_candidate
  lock_candidate="$(mktemp "${PKG_LOCK_FILE}.upgrade.XXXXXX")" || {
    log_err "Could not prepare a lockfile update for '$pkg_name'."
    rm -rf "$transaction_dir"
    return 1
  }
  if ! cp -p "$PKG_LOCK_FILE" "$lock_candidate"; then
    log_err "Could not prepare a lockfile update for '$pkg_name'."
    rm -f "$lock_candidate"
    rm -rf "$transaction_dir"
    return 1
  fi
  if [ "$package_removed" -eq 1 ]; then
    if ! upgrade_remove_lock_candidate "$lock_candidate" "$pkg_name"; then
      log_err "Could not prepare a lockfile update for '$pkg_name'."
      rm -f "$lock_candidate"
      rm -rf "$transaction_dir"
      return 1
    fi
  elif ! upgrade_write_lock_candidate "$lock_candidate" "$pkg_name" "$source" "$pkg_type" "$current_sha" "$source_repo" "$pkg_path" "${installed_paths[@]}"; then
    log_err "Could not prepare a lockfile update for '$pkg_name'."
    rm -f "$lock_candidate"
    rm -rf "$transaction_dir"
    return 1
  fi

  local backup_root="$transaction_dir/backup"
  mkdir -p "$backup_root" || {
    log_err "Could not prepare rollback data for '$pkg_name'."
    rm -f "$lock_candidate"
    rm -rf "$transaction_dir"
    return 1
  }

  for path in "${affected_paths[@]}"; do
    target="$AGENTS_ORCHESTRA_DIR_ABS/$path"
    if [ -e "$target" ] || [ -L "$target" ]; then
      if [ ! -f "$target" ] && [ ! -L "$target" ]; then
        log_err "Cannot safely update '$pkg_name': '$target' is not a file or symlink."
        rm -f "$lock_candidate"
        rm -rf "$transaction_dir"
        return 1
      fi
      local backup="$backup_root/$path"
      if ! mkdir -p "$(dirname "$backup")" || ! cp -a "$target" "$backup"; then
        log_err "Could not prepare rollback data for '$target'; the installed package was not changed."
        rm -f "$lock_candidate"
        rm -rf "$transaction_dir"
        return 1
      fi
    fi
  done

  local new_dirs=() removed_dirs=()
  declare -A new_dirs_map=()
  for path in "${installed_paths[@]}"; do
    target="$AGENTS_ORCHESTRA_DIR_ABS/$path"
    upgrade_record_missing_parent_dirs "$target" new_dirs new_dirs_map
  done

  local apply_error=""
  for path in "${installed_paths[@]}"; do
    target="$AGENTS_ORCHESTRA_DIR_ABS/$path"
    if ! mkdir -p "$(dirname "$target")"; then
      apply_error="Could not create the install directory for '$target'."
      break
    fi
    if { [ -e "$target" ] || [ -L "$target" ]; } && ! rm -f "$target"; then
      apply_error="Could not replace existing package file '$target'."
      break
    fi
    if ! cp -a "$stage_root/$path" "$target"; then
      apply_error="Could not install updated package file '$target'."
      break
    fi
  done

  if [ -z "$apply_error" ]; then
    for path in "${remove_paths[@]}"; do
      target="$AGENTS_ORCHESTRA_DIR_ABS/$path"
      if { [ -e "$target" ] || [ -L "$target" ]; } && ! rm -f "$target"; then
        apply_error="Could not remove stale package file '$target'."
        break
      fi
    done
  fi

  if [ -z "$apply_error" ] && [ -n "$package_root" ]; then
    for path in "${remove_paths[@]}"; do
      if ! upgrade_prune_empty_package_dirs "$path" "$package_root" removed_dirs; then
        apply_error="Could not clean up empty directories for '$pkg_name'."
        break
      fi
    done
  fi

  if [ -z "$apply_error" ] && ! mv -f "$lock_candidate" "$PKG_LOCK_FILE"; then
    apply_error="Could not update the package lockfile for '$pkg_name'."
  fi

  if [ -n "$apply_error" ]; then
    log_err "$apply_error"
    local rollback_rc=0
    upgrade_restore_transaction "$backup_root" affected_paths removed_dirs new_dirs || rollback_rc=$?
    if [ "$rollback_rc" -ne 0 ]; then
      log_err "Rollback for '$pkg_name' was incomplete; inspect the package files and lockfile before retrying."
    fi
    rm -f "$lock_candidate"
    rm -rf "$transaction_dir"
    return 1
  fi

  if ! rm -rf "$transaction_dir"; then
    log_warn "Upgrade succeeded, but temporary rollback data could not be removed: $transaction_dir"
  fi
  if [ "$package_removed" -eq 1 ]; then
    local removed_file_count="${#remove_paths[@]}"
    local kept_file_count
    kept_file_count=$((${#stale_paths[@]} - removed_file_count))
    log_info "Resolved '$pkg_name' after its removal from '$source' (lock entry removed; $removed_file_count file(s) removed, $kept_file_count kept)."
    return 3
  fi
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
    case "$rc" in
      2|3) return 0 ;;
      *) return "$rc" ;;
    esac
  fi

  sources_ensure_file
  upgrade_refresh_subscribed_sources

  local pkgs=()
  _upgrade_collect() { pkgs+=("$1"); }
  if [ -f "$PKG_LOCK_FILE" ]; then
    yaml_lock_each "$PKG_LOCK_FILE" _upgrade_collect
  fi

  local upgraded=0 removed=0 unchanged=0 skipped=0
  for p in "${pkgs[@]}"; do
    local rc=0
    upgrade_one "$p" >/dev/null || rc=$?
    case "$rc" in
      0)  upgraded=$((upgraded + 1)) ;;
      2)  unchanged=$((unchanged + 1)) ;;
      3)  removed=$((removed + 1)) ;;
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
  log_info "Upgrade complete: $upgraded upgraded, $removed removed from sources, $unchanged up to date, $skipped skipped."
  if [ "$subscription_added" -gt 0 ] || [ "$subscription_skipped" -gt 0 ]; then
    log_info "Subscription sync complete: $subscription_added new package(s) added, $subscription_skipped skipped."
  fi
}
