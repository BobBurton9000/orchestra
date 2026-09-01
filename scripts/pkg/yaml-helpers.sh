#!/bin/bash

set -euo pipefail

YQ_BIN="${YQ_BIN:-yq}"

require_yq() {
  if ! command -v "$YQ_BIN" >/dev/null 2>&1; then
    die "yq ('$YQ_BIN') not found on PATH. Install it (mikefarah/yq or kislyuk/yq) and ensure it is on your PATH."
  fi
}

yaml_file_ensure() {
  local file="$1"
  local top_key="$2"
  if [ ! -f "$file" ]; then
    printf '%s: []\n' "$top_key" > "$file"
  fi
}

yaml_manifest_each() {
  local file="$1"
  local callback="$2"
  shift 2
  require_yq
  [ -f "$file" ] || return 0
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local fields=()
    IFS=$'\t' read -r -a fields <<< "$line"
    [ "${#fields[@]}" -ge 3 ] || continue
    "$callback" "${fields[@]}" "$@" || true
  done < <("$YQ_BIN" -r '.packages[] | "\(.name)\t\(.type)\t\(.path)"' "$file" 2>/dev/null)
}

yaml_manifest_find() {
  local file="$1"
  local pkg_name="$2"
  require_yq
  [ -f "$file" ] || return 1
  "$YQ_BIN" -r --arg n "$pkg_name" '.packages[] | select(.name == $n) | "\(.name)\t\(.type)\t\(.path)"' "$file" 2>/dev/null | head -n1
}

yaml_manifest_count() {
  local file="$1"
  require_yq
  [ -f "$file" ] || { printf '0'; return 0; }
  "$YQ_BIN" -r '.packages | length' "$file" 2>/dev/null || printf '0'
}

yaml_sources_each() {
  local file="$1"
  local callback="$2"
  shift 2
  require_yq
  [ -f "$file" ] || return 0
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local fields=()
    IFS=$'\t' read -r -a fields <<< "$line"
    [ "${#fields[@]}" -ge 2 ] || continue
    "$callback" "${fields[@]}" "$@" || true
  done < <("$YQ_BIN" -r '.sources[] | "\(.name)\t\(.repo)\t\(.subscribed_since // "")"' "$file" 2>/dev/null)
}

yaml_sources_find_repo() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 1
  local repo
  repo="$("$YQ_BIN" -r --arg n "$name" '.sources[] | select(.name == $n) | .repo' "$file" 2>/dev/null | head -n1)"
  [ -n "$repo" ] || return 1
  printf '%s\n' "$repo"
}

yaml_sources_find_name() {
  local file="$1"
  local repo="$2"
  require_yq
  [ -f "$file" ] || return 1
  local name
  name="$("$YQ_BIN" -r --arg r "$repo" '.sources[] | select(.repo == $r) | .name' "$file" 2>/dev/null | head -n1)"
  [ -n "$name" ] || return 1
  printf '%s\n' "$name"
}

yaml_sources_subscription_sha() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 1
  local sha
  sha="$("$YQ_BIN" -r --arg n "$name" '.sources[] | select(.name == $n) | (.subscribed_since // "")' "$file" 2>/dev/null | head -n1)"
  [ -n "$sha" ] || return 1
  printf '%s\n' "$sha"
}

yaml_sources_add() {
  local file="$1"
  local name="$2"
  local repo="$3"
  require_yq
  yaml_file_ensure "$file" "sources"
  "$YQ_BIN" -y -i --arg n "$name" --arg r "$repo" \
    '.sources += [{"name": $n, "repo": $r}]' "$file"
}

yaml_sources_remove() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 0
  "$YQ_BIN" -y -i --arg n "$name" \
    '.sources |= map(select(.name != $n))' "$file"
}

yaml_sources_set_subscription() {
  local file="$1"
  local name="$2"
  local sha="${3:-}"
  require_yq
  [ -f "$file" ] || return 1

  if [ -n "$sha" ]; then
    "$YQ_BIN" -y -i --arg n "$name" --arg h "$sha" \
      '.sources |= map(if .name == $n then .subscribed_since = $h else . end)' "$file"
  else
    "$YQ_BIN" -y -i --arg n "$name" \
      '.sources |= map(if .name == $n then del(.subscribed_since) else . end)' "$file"
  fi
}

yaml_manifest_has_package() {
  local file="$1"
  local pkg_name="$2"
  require_yq
  [ -f "$file" ] || return 1
  "$YQ_BIN" -e -r --arg n "$pkg_name" \
    '.packages[] | select(.name == $n)' "$file" >/dev/null 2>&1
}

yaml_lock_each() {
  local file="$1"
  local callback="$2"
  shift 2
  require_yq
  [ -f "$file" ] || return 0
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    local fields=()
    IFS=$'\t' read -r -a fields <<< "$line"
    [ "${#fields[@]}" -ge 5 ] || continue
    "$callback" "${fields[@]}" "$@" || true
  done < <("$YQ_BIN" -r '.packages[] | "\(.name)\t\(.source)\t\(.type)\t\(.sha)\t\(.paths | join("|"))\t\(.forked // false)"' "$file" 2>/dev/null)
}

yaml_lock_field() {
  local file="$1"
  local pkg="$2"
  local field="$3"
  require_yq
  [ -f "$file" ] || return 1
  case "$field" in
    name)   "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | .name'  "$file" 2>/dev/null | head -n1 ;;
    source) "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | .source' "$file" 2>/dev/null | head -n1 ;;
    type)   "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | .type'   "$file" 2>/dev/null | head -n1 ;;
    sha)    "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | .sha'    "$file" 2>/dev/null | head -n1 ;;
    paths)  "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | .paths | join("|")' "$file" 2>/dev/null | head -n1 ;;
    forked) "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | (.forked // false)' "$file" 2>/dev/null | head -n1 ;;
    *) return 1 ;;
  esac
}

yaml_lock_is_installed() {
  local file="$1"
  local pkg="$2"
  [ -f "$file" ] || return 1
  local name
  name="$(yaml_lock_field "$file" "$pkg" name 2>/dev/null || true)"
  [ -n "$name" ]
}

yaml_lock_paths_lines() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 1
  "$YQ_BIN" -r --arg n "$pkg" '.packages[] | select(.name == $n) | .paths[]' "$file" 2>/dev/null
}

yaml_lock_write_entry() {
  local file="$1"
  local pkg="$2"
  local source="$3"
  local type="$4"
  local sha="$5"
  shift 5
  local paths=("$@")

  require_yq
  yaml_file_ensure "$file" "packages"

  local tmp
  tmp="$(mktemp)"
  cp "$file" "$tmp"

  "$YQ_BIN" -y -i --arg n "$pkg" --arg s "$source" --arg t "$type" --arg h "$sha" \
    '.packages |= map(select(.name != $n))' "$tmp"

  local paths_json='['
  local first=1
  for p in "${paths[@]}"; do
    [ -n "$p" ] || continue
    if [ "$first" -eq 1 ]; then
      first=0
    else
      paths_json+=','
    fi
    local esc
    esc="$(printf '%s' "$p" | "$YQ_BIN" -r 'tojson' - 2>/dev/null || printf '"%s"' "$p")"
    paths_json+="$esc"
  done
  paths_json+=']'

  "$YQ_BIN" -y -i --arg n "$pkg" --arg s "$source" --arg t "$type" --arg h "$sha" \
    --argjson paths "$paths_json" \
    '.packages += [{"name": $n, "source": $s, "type": $t, "sha": $h, "paths": $paths}]' "$tmp"

  mv "$tmp" "$file"
}

yaml_lock_remove_entry() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 0
  "$YQ_BIN" -y -i --arg n "$pkg" \
    '.packages |= map(select(.name != $n))' "$file"
}

yaml_lock_mark_forked() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 1
  "$YQ_BIN" -y -i --arg n "$pkg" \
    '.packages |= map(if .name == $n then .forked = true else . end)' "$file"
}
