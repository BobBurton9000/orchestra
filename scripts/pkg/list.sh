#!/bin/bash

set -euo pipefail

list_installed() {
  ensure_orchestra_dir
  [ -f "$PKG_LOCK_FILE" ] || {
    echo "No packages installed."
    return 0
  }

  local count=0
  echo "Installed packages ($PKG_LOCK_FILE):"
  echo ""
  printf '  %-30s %-12s %-12s %s\n' "PACKAGE" "SOURCE" "TYPE" "SHA"
  _list_installed_print() {
    local source="$2"
    [ "${6:-false}" = "true" ] && source="$source (forked)"
    printf '  %-30s %-12s %-12s %s\n' "$1" "$source" "$3" "${4:0:12}"
    count=$((count + 1))
  }
  yaml_lock_each "$PKG_LOCK_FILE" _list_installed_print
  echo ""
  echo "  Total: $count"
}

list_available_all_sources() {
  ensure_pkg_dirs
  sources_ensure_file

  local any=0
  _list_available_inner() {
    local pkg="$1" type="$2" path="$3"
    printf '  %-30s %-12s %s\n' "$pkg" "$type" "$path"
    any=$((any + 1))
  }
  _list_available_source() {
    local sname="$1" srepo="$2"
    if ! index_ensure_cached "$sname"; then
      log_warn "Source '$sname' not cached. Run 'orchestra update'."
      return
    fi
    local sha
    sha="$(index_get_sha "$sname")"
    echo ""
    echo "Source: $sname ($srepo @ ${sha:0:12})"
    printf '  %-30s %-12s %s\n' "PACKAGE" "TYPE" "PATH"
    yaml_manifest_each "$(index_cache_dir_for "$sname")/manifest.yaml" _list_available_inner
  }
  yaml_sources_each "$PKG_SOURCES_FILE" _list_available_source

  [ "$any" -eq 0 ] && echo "No packages available. Add a source and run 'orchestra update'."
}

list_cmd() {
  local flag="${1:-}"
  case "$flag" in
    --available|-a)
      list_available_all_sources
      ;;
    "")
      list_installed
      ;;
    *)
      die "Unknown flag: $flag. Usage: orchestra list [--available]"
      ;;
  esac
}

search_cmd() {
  local term="${1:-}"
  [ -n "$term" ] || die "Usage: orchestra search <term>"

  ensure_pkg_dirs
  sources_ensure_file

  local found=0
  _search_inner() {
    local pkg="$1" type="$2" path="$3" sname="$4"
    local lower_pkg="${pkg,,}" lower_type="${type,,}" lower_path="${path,,}" lower_term="${term,,}"
    if [[ "$lower_pkg" == *"$lower_term"* ]] || [[ "$lower_type" == *"$lower_term"* ]] || [[ "$lower_path" == *"$lower_term"* ]]; then
      printf '%s\t%s\t%s\t%s\n' "$pkg" "$type" "$sname" "$path"
      found=$((found + 1))
    fi
  }
  _search_source() {
    local sname="$1"
    if ! index_ensure_cached "$sname"; then
      return
    fi
    yaml_manifest_each "$(index_cache_dir_for "$sname")/manifest.yaml" _search_inner "$sname"
  }
  yaml_sources_each "$PKG_SOURCES_FILE" _search_source

  if [ "$found" -eq 0 ]; then
    echo "No packages matching '$term'."
  fi
}

info_cmd() {
  local pkg="${1:-}"
  [ -n "$pkg" ] || die "Usage: orchestra info <pkg>"

  ensure_orchestra_dir

  if lock_is_installed "$pkg"; then
    local source type sha paths forked
    source="$(lock_get_source "$pkg")"
    type="$(lock_get_type "$pkg")"
    sha="$(lock_get_sha "$pkg")"
    paths="$(lock_get_paths "$pkg")"
    forked="$(lock_get_forked "$pkg")"

    echo "Package: $pkg"
    if [ "$forked" = "true" ]; then
      echo "  Status:    forked"
      echo "  Source:    $source (detached)"
    else
      echo "  Status:    installed"
      echo "  Source:    $source"
    fi
    echo "  Type:      $type"
    echo "  Head SHA:  $sha"
    echo "  Installed paths:"
    IFS='|' read -ra parr <<< "$paths"
    for p in "${parr[@]}"; do
      echo "    - $p"
    done

    local current_sha=""
    if [ "$forked" = "true" ]; then
      echo "  Upgrade:   disabled (forked copy)"
    elif index_ensure_cached "$source"; then
      current_sha="$(index_get_sha "$source")"
      if [ "$current_sha" != "$sha" ]; then
        echo "  Upgrade available: $current_sha"
      else
        echo "  Up to date."
      fi
    fi
  else
    ensure_pkg_dirs
    sources_ensure_file

    local found=""
    found="$(index_find_package "$pkg" || true)"
    if [ -n "$found" ]; then
      local source_name source_repo pkg_type pkg_path
      IFS=$'\t' read -r source_name source_repo pkg_type pkg_path <<< "$found"
      local sha=""
      index_ensure_cached "$source_name" && sha="$(index_get_sha "$source_name")"

      echo "Package: $pkg"
      echo "  Status:    available (not installed)"
      echo "  Source:    $source_name ($source_repo)"
      echo "  Type:      $pkg_type"
      echo "  Path:      $pkg_path"
      [ -n "$sha" ] && echo "  Head SHA:  $sha"
    else
      die "No package named '$pkg' found in cached sources. Run 'orchestra update' to refresh."
    fi
  fi
}
