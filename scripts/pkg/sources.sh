#!/bin/bash

set -euo pipefail

sources_default_content() {
  cat <<EOF
# Orchestra sources — personal list of package sources.
# Edit via 'orchestra source add/remove'.
sources:
  - name: core
    repo: BobBurton9000/orchestra-defaults
EOF
}

sources_ensure_file() {
  ensure_orchestra_dir
  if [ ! -f "$PKG_SOURCES_FILE" ]; then
    sources_default_content > "$PKG_SOURCES_FILE"
    log_info "Created default $PKG_SOURCES_FILE (core -> BobBurton9000/orchestra-defaults)"
  fi
}

sources_list_all() {
  sources_ensure_file
  _sources_print_pair() { printf '%s\t%s\n' "$1" "$2"; }
  yaml_sources_each "$PKG_SOURCES_FILE" _sources_print_pair
}

sources_lookup_repo() {
  local name="$1"
  sources_ensure_file
  yaml_sources_find_repo "$PKG_SOURCES_FILE" "$name"
}

sources_lookup_name() {
  local repo="$1"
  sources_ensure_file
  yaml_sources_find_name "$PKG_SOURCES_FILE" "$repo"
}

sources_add() {
  local repo="$1"
  local name="${2:-}"

  if [[ "$repo" != */* ]]; then
    die "Source must be <owner>/<repo>. Got: $repo"
  fi

  sources_ensure_file

  if sources_lookup_name "$repo" >/dev/null 2>&1; then
    local existing_name
    existing_name="$(sources_lookup_name "$repo")"
    die "Repository $repo is already configured as source '$existing_name'. Remove it first if you want to re-add it under a different name."
  fi

  if [ -z "$name" ]; then
    name="${repo#*/}"
    name="${name#orchestra-}"
  fi

  if sources_lookup_repo "$name" >/dev/null 2>&1; then
    die "Source name '$name' is already in use. Choose a different name: orchestra source add $repo <name>"
  fi

  yaml_sources_add "$PKG_SOURCES_FILE" "$name" "$repo"
  log_info "Added source '$name' -> $repo"
}

sources_remove() {
  local name="$1"
  sources_ensure_file

  if ! sources_lookup_repo "$name" >/dev/null 2>&1; then
    die "No source named '$name' is configured."
  fi

  if [ -f "$PKG_LOCK_FILE" ]; then
    _sources_remove_check() {
      if [ "$2" = "$name" ]; then
        die "Cannot remove source '$name': package '$1' is still installed. Run 'orchestra remove $1' first."
      fi
    }
    yaml_lock_each "$PKG_LOCK_FILE" _sources_remove_check
  fi

  yaml_sources_remove "$PKG_SOURCES_FILE" "$name"
  log_info "Removed source '$name'"
}

sources_cmd_list() {
  sources_ensure_file
  echo "Configured sources ($PKG_SOURCES_FILE):"
  echo ""
  _sources_cmd_list_print() { printf '  %-20s %s\n' "$1" "$2"; }
  yaml_sources_each "$PKG_SOURCES_FILE" _sources_cmd_list_print
}