#!/bin/bash

set -euo pipefail

migrate_v2_is_orchestra_checkout() {
  local directory="$1"
  [ -f "$directory/orchestra.sh" ] &&
    [ -f "$directory/scripts/common.sh" ] &&
    [ -f "$directory/scripts/pkg/cli.sh" ]
}

migrate_v2_copy_file() {
  local relative_path="$1"
  local source_file="$MIGRATE_V2_LEGACY_DIR/$relative_path"
  local destination_file="$MIGRATE_V2_STATE_DIR/$relative_path"

  [ -f "$source_file" ] || return 0

  if [ -e "$destination_file" ] || [ -L "$destination_file" ]; then
    if [ -f "$destination_file" ] && cmp -s "$source_file" "$destination_file"; then
      log_info "Already migrated: $relative_path"
    else
      log_warn "Migration conflict at $destination_file; leaving both copies untouched."
      MIGRATE_V2_CONFLICTS=$((MIGRATE_V2_CONFLICTS + 1))
    fi
    return 0
  fi

  local parent_dir
  parent_dir="$(dirname "$destination_file")"
  while [[ "$parent_dir" == "$MIGRATE_V2_STATE_DIR"* ]]; do
    if [ -e "$parent_dir" ] && [ ! -d "$parent_dir" ]; then
      log_warn "Migration conflict: $parent_dir is not a directory; leaving source untouched."
      MIGRATE_V2_CONFLICTS=$((MIGRATE_V2_CONFLICTS + 1))
      return 0
    fi
    [ "$parent_dir" = "$MIGRATE_V2_STATE_DIR" ] && break
    parent_dir="$(dirname "$parent_dir")"
  done

  mkdir -p "$(dirname "$destination_file")"
  cp -pn -- "$source_file" "$destination_file"
  if ! cmp -s "$source_file" "$destination_file"; then
    log_warn "Migration conflict at $destination_file; leaving both copies untouched."
    MIGRATE_V2_CONFLICTS=$((MIGRATE_V2_CONFLICTS + 1))
    return 0
  fi
  log_info "Migrated $relative_path"
  MIGRATE_V2_COPIED=$((MIGRATE_V2_COPIED + 1))
}

migrate_v2() {
  local legacy_dir="$ORCHESTRA_PROJECT_ROOT/.orchestra"
  local state_dir="$ORCHESTRA_PROJECT_ROOT/$ORCHESTRA_DIR"

  [ "$state_dir" != "$legacy_dir" ] ||
    die "ORCHESTRA_DIR points at the legacy .orchestra directory; unset it before running 'orchestra migrate v2'."
  case "$state_dir/" in
    "$legacy_dir/"*) die "ORCHESTRA_DIR points inside the legacy .orchestra directory; unset it before running 'orchestra migrate v2'." ;;
  esac
  [ -d "$legacy_dir" ] || die "No legacy directory found at $legacy_dir. Run this from the project that contains the old .orchestra/ directory."

  MIGRATE_V2_LEGACY_DIR="$legacy_dir"
  MIGRATE_V2_STATE_DIR="$state_dir"
  MIGRATE_V2_COPIED=0
  MIGRATE_V2_CONFLICTS=0

  local relative_path
  for relative_path in sources.yaml pkg.lock.yaml config.yml .manifest; do
    migrate_v2_copy_file "$relative_path"
  done

  if [ -d "$legacy_dir/pkg-cache" ]; then
    local source_file
    while IFS= read -r -d '' source_file; do
      relative_path="${source_file#"$legacy_dir/"}"
      migrate_v2_copy_file "$relative_path"
    done < <(find "$legacy_dir/pkg-cache" -type f -print0)
  fi

  if [ "$MIGRATE_V2_CONFLICTS" -gt 0 ]; then
    log_err "Migrated $MIGRATE_V2_COPIED file(s), but found $MIGRATE_V2_CONFLICTS conflict(s). Resolve them and rerun 'orchestra migrate v2'. The legacy .orchestra/ directory was retained."
    return 1
  fi

  log_info "Legacy state migration complete ($MIGRATE_V2_COPIED file(s) copied)."

  if ! migrate_v2_is_orchestra_checkout "$legacy_dir"; then
    log_warn "State was migrated, but $legacy_dir was left in place because it is not a recognized Orchestra checkout."
    return 0
  fi

  if ! ask_yes_no "Remove the old Orchestra checkout at $legacy_dir?"; then
    log_info "Kept the old checkout at $legacy_dir."
    return 0
  fi

  rm -rf -- "$legacy_dir"
  log_info "Removed the old Orchestra checkout at $legacy_dir."
}

migrate_cmd() {
  local version="${1:-}"
  [ "$#" -eq 1 ] && [ "$version" = "v2" ] ||
    die "Usage: orchestra migrate v2"
  migrate_v2
}
