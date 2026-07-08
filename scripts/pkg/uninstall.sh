#!/bin/bash

set -euo pipefail

uninstall_remove() {
  local pkg_name="$1"

  ensure_orchestra_dir

  if ! lock_is_installed "$pkg_name"; then
    die "Package '$pkg_name' is not installed. Run 'orchestra list' to see installed packages."
  fi

  local paths
  paths="$(lock_get_paths "$pkg_name")"
  [ -n "$paths" ] || die "Lockfile entry for '$pkg_name' has no recorded paths. Refusing to remove blindly."

  local source
  source="$(lock_get_source "$pkg_name")"

  if ! ask_remove "$pkg_name"; then
    log_info "Skipped."
    return 0
  fi

  local deleted=0 missing=0 rel_path
  while IFS= read -r rel_path; do
    [ -n "$rel_path" ] || continue
    local abs="$rel_path"
    case "$rel_path" in
      agents/*)    abs="$AGENTS_ORCHESTRA_DIR_ABS/$rel_path" ;;
      prompts/*)   abs="$AGENTS_ORCHESTRA_DIR_ABS/$rel_path" ;;
      skills/*)    abs="$AGENTS_ORCHESTRA_DIR_ABS/$rel_path" ;;
      *)           abs="$rel_path" ;;
    esac

    if [ -f "$abs" ]; then
      rm -f "$abs"
      deleted=$((deleted + 1))
    else
      missing=$((missing + 1))
    fi
  done < <(yaml_lock_paths_lines "$PKG_LOCK_FILE" "$pkg_name")

  local target_dir=""
  case "$(lock_get_type "$pkg_name")" in
    agent)      target_dir="$AGENTS_ORCHESTRA_DIR_ABS/agents" ;;
    prompt)     target_dir="$AGENTS_ORCHESTRA_DIR_ABS/prompts" ;;
    prompt-dir) target_dir="$AGENTS_ORCHESTRA_DIR_ABS/prompts/${pkg_name}" ;;
    skill)      target_dir="$AGENTS_ORCHESTRA_DIR_ABS/skills/${pkg_name}" ;;
  esac

  if [ -n "$target_dir" ] && [ -d "$target_dir" ]; then
    case "$(lock_get_type "$pkg_name")" in
      prompt-dir|skill)
        rmdir "$target_dir" 2>/dev/null || true
        ;;
    esac
  fi

  lock_remove_entry "$pkg_name"

  log_info "Removed '$pkg_name' from source '$source' ($deleted file(s) deleted, $missing already absent)."
}

uninstall_cmd() {
  local pkg="${1:-}"
  [ -n "$pkg" ] || die "Usage: orchestra remove <pkg>"
  uninstall_remove "$pkg"
}