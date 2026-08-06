#!/bin/bash

set -euo pipefail

status_display_path() {
  local rel_path="$1"
  printf '%s/%s' "$AGENTS_ORCHESTRA_DIR" "$rel_path"
}

status_absolute_path() {
  local rel_path="$1"
  printf '%s/%s' "$AGENTS_ORCHESTRA_DIR_ABS" "$rel_path"
}

status_cmd() {
  ensure_orchestra_dir

  local package_count=0
  local managed_count=0
  local missing_count=0
  local untracked_count=0
  local path absolute_path
  declare -A managed_paths=()

  echo "Orchestra status"
  echo ""
  echo "Definitions: $AGENTS_ORCHESTRA_DIR"
  echo "Lockfile:    $ORCHESTRA_DIR/pkg.lock.yaml"
  echo ""

  if [ -f "$PKG_LOCK_FILE" ]; then
    echo "Installed packages:"
    echo ""

    _status_print_package() {
      local pkg="$1"
      local source="$2"
      local type="$3"
      local sha="$4"
      local paths="$5"
      local present=0
      local missing=0
      local path
      local absolute_path
      local -a package_paths=()

      IFS='|' read -r -a package_paths <<< "$paths"
      for path in "${package_paths[@]}"; do
        [ -n "$path" ] || continue

        if [ -z "${managed_paths[$path]+set}" ]; then
          managed_count=$((managed_count + 1))
        fi
        managed_paths["$path"]="$pkg"

        absolute_path="$(status_absolute_path "$path")"
        if [ -f "$absolute_path" ] || [ -L "$absolute_path" ]; then
          present=$((present + 1))
        else
          missing=$((missing + 1))
          missing_count=$((missing_count + 1))
        fi
      done

      package_count=$((package_count + 1))

      local package_status="OK"
      if [ "$missing" -gt 0 ] && [ "$present" -gt 0 ]; then
        package_status="PARTIAL"
      elif [ "$missing" -gt 0 ]; then
        package_status="MISSING"
      elif [ "$present" -eq 0 ]; then
        package_status="NO PATHS"
      fi

      printf '  [%s] %s (%s, %s @ %s)\n' \
        "$package_status" "$pkg" "$type" "$source" "${sha:0:12}"

      for path in "${package_paths[@]}"; do
        [ -n "$path" ] || continue
        absolute_path="$(status_absolute_path "$path")"
        if [ -f "$absolute_path" ] || [ -L "$absolute_path" ]; then
          printf '      [TRACKED] %s\n' "$(status_display_path "$path")"
        else
          printf '      [MISSING] %s\n' "$(status_display_path "$path")"
        fi
      done
    }

    yaml_lock_each "$PKG_LOCK_FILE" _status_print_package
    if [ "$package_count" -eq 0 ]; then
      echo "  No packages installed."
    fi
  else
    echo "Installed packages: none (no lockfile)"
  fi

  echo ""
  echo "Files not part of a package:"
  if [ -d "$AGENTS_ORCHESTRA_DIR_ABS" ]; then
    while IFS= read -r -d '' absolute_path; do
      path="${absolute_path#"$AGENTS_ORCHESTRA_DIR_ABS/"}"
      if [ -z "${managed_paths[$path]+set}" ]; then
        printf '  [UNTRACKED] %s\n' "$(status_display_path "$path")"
        untracked_count=$((untracked_count + 1))
      fi
    done < <(find "$AGENTS_ORCHESTRA_DIR_ABS" \( -type f -o -type l \) -print0)
  fi
  if [ "$untracked_count" -eq 0 ]; then
    echo "  None."
  fi

  echo ""
  printf 'Summary: %d package(s), %d managed file(s), %d missing file(s), %d file(s) not part of a package.\n' \
    "$package_count" "$managed_count" "$missing_count" "$untracked_count"

  # Keep status informational. Findings are shown in the report rather than
  # turning a useful inspection command into a failing shell step.
  return 0
}
