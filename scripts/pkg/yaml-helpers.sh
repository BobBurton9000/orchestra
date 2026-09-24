#!/bin/bash

set -euo pipefail

YQ_BIN="${YQ_BIN:-yq}"
YQ_OUTPUT_ARGS=()
YQ_OUTPUT_ARGS_READY=0

require_yq() {
  if ! command -v "$YQ_BIN" >/dev/null 2>&1; then
    die "yq ('$YQ_BIN') not found on PATH. Install it (mikefarah/yq or kislyuk/yq) and ensure it is on your PATH."
  fi
  if [ "$YQ_OUTPUT_ARGS_READY" -eq 0 ]; then
    local yq_help
    yq_help="$("$YQ_BIN" --help 2>&1 || true)"
    if [[ "$yq_help" == *"--yaml-output"* ]]; then
      YQ_OUTPUT_ARGS=(-y)
    fi
    YQ_OUTPUT_ARGS_READY=1
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
  YQ_PACKAGE_NAME="$pkg_name" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | "\(.name)\t\(.type)\t\(.path)"' "$file" 2>/dev/null | head -n1
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
  done < <("$YQ_BIN" -r '.sources[] | [(.name // ""), (.repo // ""), (.subscribed_since // "")] | join("\t")' "$file" 2>/dev/null)
}

yaml_sources_find_repo() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 1
  local repo
  repo="$(YQ_SOURCE_NAME="$name" "$YQ_BIN" -r '.sources[] | select(.name == strenv(YQ_SOURCE_NAME)) | .repo' "$file" 2>/dev/null | head -n1)"
  [ -n "$repo" ] || return 1
  printf '%s\n' "$repo"
}

yaml_sources_find_name() {
  local file="$1"
  local repo="$2"
  require_yq
  [ -f "$file" ] || return 1
  local name
  name="$(YQ_SOURCE_REPO="$repo" "$YQ_BIN" -r '.sources[] | select(.repo == strenv(YQ_SOURCE_REPO)) | .name' "$file" 2>/dev/null | head -n1)"
  [ -n "$name" ] || return 1
  printf '%s\n' "$name"
}

yaml_sources_subscription_sha() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 1
  local sha
  sha="$(YQ_SOURCE_NAME="$name" "$YQ_BIN" -r '.sources[] | select(.name == strenv(YQ_SOURCE_NAME)) | (.subscribed_since // "")' "$file" 2>/dev/null | head -n1)"
  [ -n "$sha" ] || return 1
  printf '%s\n' "$sha"
}

yaml_sources_add() {
  local file="$1"
  local name="$2"
  local repo="$3"
  require_yq
  yaml_file_ensure "$file" "sources"
  YQ_SOURCE_NAME="$name" YQ_SOURCE_REPO="$repo" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
    '.sources += [{"name": strenv(YQ_SOURCE_NAME), "repo": strenv(YQ_SOURCE_REPO)}]' "$file"
}

yaml_sources_remove() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 0
  YQ_SOURCE_NAME="$name" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
    '.sources |= map(select(.name != strenv(YQ_SOURCE_NAME)))' "$file"
}

yaml_sources_set_subscription() {
  local file="$1"
  local name="$2"
  local sha="${3:-}"
  require_yq
  [ -f "$file" ] || return 1

  if [ -n "$sha" ]; then
    YQ_SOURCE_NAME="$name" YQ_SUBSCRIPTION_SHA="$sha" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
      '.sources |= map((select(.name == strenv(YQ_SOURCE_NAME)) | . + {"subscribed_since": strenv(YQ_SUBSCRIPTION_SHA)}) // .)' "$file"
  else
    YQ_SOURCE_NAME="$name" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
      '.sources |= map((select(.name == strenv(YQ_SOURCE_NAME)) | del(.subscribed_since)) // .)' "$file"
  fi
}

yaml_manifest_has_package() {
  local file="$1"
  local pkg_name="$2"
  require_yq
  [ -f "$file" ] || return 1
  YQ_PACKAGE_NAME="$pkg_name" "$YQ_BIN" -e -r \
    '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME))' "$file" >/dev/null 2>&1
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
  done < <("$YQ_BIN" -r '.packages[] | [(.name // ""), (.source // ""), (.type // ""), (.sha // ""), ((.paths // []) | join("|")), (.forked // false), (.source_repo // ""), (.source_path // "")] | join("\t")' "$file" 2>/dev/null)
}

yaml_lock_field() {
  local file="$1"
  local pkg="$2"
  local field="$3"
  require_yq
  [ -f "$file" ] || return 1
  case "$field" in
    name)        YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | .name' "$file" 2>/dev/null | head -n1 ;;
    source)      YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | .source' "$file" 2>/dev/null | head -n1 ;;
    type)        YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | .type' "$file" 2>/dev/null | head -n1 ;;
    sha)         YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | .sha' "$file" 2>/dev/null | head -n1 ;;
    paths)       YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | .paths | join("|")' "$file" 2>/dev/null | head -n1 ;;
    forked)      YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | (.forked // false)' "$file" 2>/dev/null | head -n1 ;;
    source_repo) YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | (.source_repo // "")' "$file" 2>/dev/null | head -n1 ;;
    source_path) YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | (.source_path // "")' "$file" 2>/dev/null | head -n1 ;;
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
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r '.packages[] | select(.name == strenv(YQ_PACKAGE_NAME)) | .paths[]' "$file" 2>/dev/null
}

yaml_lock_write_entry() {
  local file="$1"
  local pkg="$2"
  local source="$3"
  local type="$4"
  local sha="$5"
  local source_repo="$6"
  local source_path="$7"
  shift 7
  local paths=("$@")

  require_yq
  yaml_file_ensure "$file" "packages"

  local tmp
  tmp="$(mktemp)"
  cp "$file" "$tmp"

  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
    '.packages |= map(select(.name != strenv(YQ_PACKAGE_NAME)))' "$tmp"

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

  YQ_PACKAGE_NAME="$pkg" YQ_SOURCE_NAME="$source" YQ_PACKAGE_TYPE="$type" \
    YQ_PACKAGE_SHA="$sha" YQ_SOURCE_REPO="$source_repo" YQ_SOURCE_PATH="$source_path" \
    YQ_PACKAGE_PATHS="$paths_json" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
    '.packages += [{"name": strenv(YQ_PACKAGE_NAME), "source": strenv(YQ_SOURCE_NAME), "source_repo": strenv(YQ_SOURCE_REPO), "source_path": strenv(YQ_SOURCE_PATH), "type": strenv(YQ_PACKAGE_TYPE), "sha": strenv(YQ_PACKAGE_SHA), "paths": (strenv(YQ_PACKAGE_PATHS) | fromjson)}]' "$tmp"

  mv "$tmp" "$file"
}

yaml_lock_remove_entry() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 0
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
    '.packages |= map(select(.name != strenv(YQ_PACKAGE_NAME)))' "$file"
}

yaml_lock_mark_forked() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 1
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i \
    '.packages |= map((select(.name == strenv(YQ_PACKAGE_NAME)) | . + {"forked": true}) // .)' "$file"
}
