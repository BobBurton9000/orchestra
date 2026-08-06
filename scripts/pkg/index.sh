#!/bin/bash

set -euo pipefail

index_cache_dir_for() {
  local source_name="$1"
  printf '%s/%s' "$PKG_CACHE_DIR" "$source_name"
}

index_subscription_baseline_file_for() {
  local source_name="$1"
  printf '%s/subscription-baseline.yaml' "$(index_cache_dir_for "$source_name")"
}

index_refresh_source() {
  local source_name="$1"
  local owner_repo="$2"

  local cache_dir
  cache_dir="$(index_cache_dir_for "$source_name")"
  mkdir -p "$cache_dir"

  local branch sha
  branch="$(gh_default_branch "$owner_repo")"
  sha="$(gh_head_sha "$owner_repo" "$branch")"

  [ -n "$sha" ] || die "Could not fetch HEAD sha for $owner_repo"

  printf '%s\n' "$sha" > "$cache_dir/head.sha"
  printf '%s\n' "$branch" > "$cache_dir/branch"

  gh_fetch_manifest "$owner_repo" "$sha" > "$cache_dir/manifest.yaml"

  if [ ! -s "$cache_dir/manifest.yaml" ]; then
    die "Source '$source_name' ($owner_repo) has no orchestra-source.yaml at its root, or it is empty."
  fi

  printf '%s\n' "$sha"
}

index_update_all() {
  gh_check_auth
  ensure_pkg_dirs
  sources_ensure_file

  local count=0
  _index_update_one() {
    local name="$1" repo="$2"
    log_info "Updating source '$name' ($repo)..."
    index_refresh_source "$name" "$repo" >/dev/null
    count=$((count + 1))
  }
  yaml_sources_each "$PKG_SOURCES_FILE" _index_update_one

  if [ "$count" -eq 0 ]; then
    log_info "No sources configured. Add one with: orchestra source add <owner>/<repo>"
  else
    log_info "Updated $count source(s)."
  fi
}

index_ensure_cached() {
  local source_name="$1"
  local cache_dir
  cache_dir="$(index_cache_dir_for "$source_name")"

  if [ ! -f "$cache_dir/manifest.yaml" ] || [ ! -f "$cache_dir/head.sha" ]; then
    return 1
  fi
  return 0
}

index_get_sha() {
  local source_name="$1"
  local cache_dir
  cache_dir="$(index_cache_dir_for "$source_name")"
  cat "$cache_dir/head.sha" 2>/dev/null | tr -d '\r\n'
}

index_get_branch() {
  local source_name="$1"
  local cache_dir
  cache_dir="$(index_cache_dir_for "$source_name")"
  cat "$cache_dir/branch" 2>/dev/null | tr -d '\r\n'
}

index_find_package() {
  local pkg_name="$1"
  local source_name="${2:-}"

  sources_ensure_file

  while IFS= read -r line; do
    local sname srepo
    sname="${line%%$'\t'*}"
    srepo="${line#*$'\t'}"

    if [ -n "$source_name" ] && [ "$sname" != "$source_name" ]; then
      continue
    fi

    if ! index_ensure_cached "$sname"; then
      continue
    fi

    local cache_dir
    cache_dir="$(index_cache_dir_for "$sname")"

    local found_type found_path
    found_type=""
    found_path=""
    while IFS=$'\t' read -r mname mtype mpath; do
      if [ "$mname" = "$pkg_name" ]; then
        found_type="$mtype"
        found_path="$mpath"
        break
      fi
    done < <(yaml_manifest_each "$cache_dir/manifest.yaml" _manifest_emit_tsv)

    if [ -n "$found_type" ]; then
      printf '%s\t%s\t%s\t%s\n' "$sname" "$srepo" "$found_type" "$found_path"
      return 0
    fi
  done < <(yaml_sources_each "$PKG_SOURCES_FILE" _sources_emit_tsv)

  return 1
}

_manifest_emit_tsv() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
_sources_emit_tsv()   { printf '%s\t%s\n' "$1" "$2"; }

index_list_packages_in_source() {
  local source_name="$1"
  local cache_dir
  cache_dir="$(index_cache_dir_for "$source_name")"

  if [ ! -f "$cache_dir/manifest.yaml" ]; then
    return 1
  fi

  _index_list_print() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }
  yaml_manifest_each "$cache_dir/manifest.yaml" _index_list_print
}

index_list_new_packages_in_source() {
  local source_name="$1"
  local baseline_file
  baseline_file="$(index_subscription_baseline_file_for "$source_name")"

  [ -f "$baseline_file" ] || return 1

  local pkg_name pkg_type pkg_path
  while IFS=$'\t' read -r pkg_name pkg_type pkg_path; do
    [ -n "$pkg_name" ] || continue
    if ! yaml_manifest_has_package "$baseline_file" "$pkg_name"; then
      printf '%s\t%s\t%s\n' "$pkg_name" "$pkg_type" "$pkg_path"
    fi
  done < <(index_list_packages_in_source "$source_name")
}
