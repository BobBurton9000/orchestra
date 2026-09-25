#!/bin/bash

set -euo pipefail

YQ_BIN="${YQ_BIN:-yq}"
YQ_OUTPUT_ARGS=()
YQ_OUTPUT_ARGS_READY=0
YQ_DIALECT=""

require_yq() {
  if ! command -v "$YQ_BIN" >/dev/null 2>&1; then
    die "yq ('$YQ_BIN') not found on PATH. Install it (mikefarah/yq or kislyuk/yq) and ensure it is on your PATH."
  fi
  if [ "$YQ_OUTPUT_ARGS_READY" -eq 0 ]; then
    local yq_help
    yq_help="$("$YQ_BIN" --help 2>&1 || true)"
    if [[ "$yq_help" == *"--yaml-output"* ]]; then
      YQ_OUTPUT_ARGS=(-y)
      YQ_DIALECT="kislyuk"
    else
      YQ_DIALECT="mikefarah"
    fi
    YQ_OUTPUT_ARGS_READY=1
  fi
}

yaml_env_ref() {
  local variable="$1"
  require_yq
  if [ "$YQ_DIALECT" = "kislyuk" ]; then
    printf 'env.%s' "$variable"
  else
    printf 'strenv(%s)' "$variable"
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
  local package_name_expr
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  YQ_PACKAGE_NAME="$pkg_name" "$YQ_BIN" -r \
    ".packages[] | select(.name == ${package_name_expr}) | \"\\(.name)\\t\\(.type)\\t\\(.path)\"" \
    "$file" 2>/dev/null | head -n1
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
  local repo source_name_expr
  source_name_expr="$(yaml_env_ref YQ_SOURCE_NAME)"
  repo="$(YQ_SOURCE_NAME="$name" "$YQ_BIN" -r \
    ".sources[] | select(.name == ${source_name_expr}) | .repo" "$file" 2>/dev/null | head -n1)"
  [ -n "$repo" ] || return 1
  printf '%s\n' "$repo"
}

yaml_sources_find_name() {
  local file="$1"
  local repo="$2"
  require_yq
  [ -f "$file" ] || return 1
  local name source_repo_expr
  source_repo_expr="$(yaml_env_ref YQ_SOURCE_REPO)"
  name="$(YQ_SOURCE_REPO="$repo" "$YQ_BIN" -r \
    ".sources[] | select(.repo == ${source_repo_expr}) | .name" "$file" 2>/dev/null | head -n1)"
  [ -n "$name" ] || return 1
  printf '%s\n' "$name"
}

yaml_sources_subscription_sha() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 1
  local sha source_name_expr
  source_name_expr="$(yaml_env_ref YQ_SOURCE_NAME)"
  sha="$(YQ_SOURCE_NAME="$name" "$YQ_BIN" -r \
    ".sources[] | select(.name == ${source_name_expr}) | (.subscribed_since // \"\")" \
    "$file" 2>/dev/null | head -n1)"
  [ -n "$sha" ] || return 1
  printf '%s\n' "$sha"
}

yaml_sources_add() {
  local file="$1"
  local name="$2"
  local repo="$3"
  require_yq
  yaml_file_ensure "$file" "sources"
  local source_name_expr source_repo_expr query
  source_name_expr="$(yaml_env_ref YQ_SOURCE_NAME)"
  source_repo_expr="$(yaml_env_ref YQ_SOURCE_REPO)"
  query=".sources += [{\"name\": ${source_name_expr}, \"repo\": ${source_repo_expr}}]"
  YQ_SOURCE_NAME="$name" YQ_SOURCE_REPO="$repo" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$file"
}

yaml_sources_remove() {
  local file="$1"
  local name="$2"
  require_yq
  [ -f "$file" ] || return 0
  local source_name_expr query
  source_name_expr="$(yaml_env_ref YQ_SOURCE_NAME)"
  query=".sources |= map(select(.name != ${source_name_expr}))"
  YQ_SOURCE_NAME="$name" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$file"
}

yaml_sources_set_subscription() {
  local file="$1"
  local name="$2"
  local sha="${3:-}"
  require_yq
  [ -f "$file" ] || return 1

  local source_name_expr subscription_sha_expr query
  source_name_expr="$(yaml_env_ref YQ_SOURCE_NAME)"
  if [ -n "$sha" ]; then
    subscription_sha_expr="$(yaml_env_ref YQ_SUBSCRIPTION_SHA)"
    query=".sources |= map((select(.name == ${source_name_expr}) | . + {\"subscribed_since\": ${subscription_sha_expr}}) // .)"
    YQ_SOURCE_NAME="$name" YQ_SUBSCRIPTION_SHA="$sha" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$file"
  else
    query=".sources |= map((select(.name == ${source_name_expr}) | del(.subscribed_since)) // .)"
    YQ_SOURCE_NAME="$name" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$file"
  fi
}

yaml_manifest_has_package() {
  local file="$1"
  local pkg_name="$2"
  require_yq
  [ -f "$file" ] || return 1
  local package_name_expr
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  YQ_PACKAGE_NAME="$pkg_name" "$YQ_BIN" -e -r \
    ".packages[] | select(.name == ${package_name_expr})" "$file" >/dev/null 2>&1
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
  local package_name_expr query
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  case "$field" in
    name)        query=".packages[] | select(.name == ${package_name_expr}) | .name" ;;
    source)      query=".packages[] | select(.name == ${package_name_expr}) | .source" ;;
    type)        query=".packages[] | select(.name == ${package_name_expr}) | .type" ;;
    sha)         query=".packages[] | select(.name == ${package_name_expr}) | .sha" ;;
    paths)       query=".packages[] | select(.name == ${package_name_expr}) | .paths | join(\"|\")" ;;
    forked)      query=".packages[] | select(.name == ${package_name_expr}) | (.forked // false)" ;;
    source_repo) query=".packages[] | select(.name == ${package_name_expr}) | (.source_repo // \"\")" ;;
    source_path) query=".packages[] | select(.name == ${package_name_expr}) | (.source_path // \"\")" ;;
    *) return 1 ;;
  esac
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r "$query" "$file" 2>/dev/null | head -n1
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
  local package_name_expr
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" -r \
    ".packages[] | select(.name == ${package_name_expr}) | .paths[]" "$file" 2>/dev/null
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

  local package_name_expr query
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  query=".packages |= map(select(.name != ${package_name_expr}))"
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$tmp"

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

  local source_name_expr source_repo_expr source_path_expr package_type_expr package_sha_expr package_paths_expr
  source_name_expr="$(yaml_env_ref YQ_SOURCE_NAME)"
  source_repo_expr="$(yaml_env_ref YQ_SOURCE_REPO)"
  source_path_expr="$(yaml_env_ref YQ_SOURCE_PATH)"
  package_type_expr="$(yaml_env_ref YQ_PACKAGE_TYPE)"
  package_sha_expr="$(yaml_env_ref YQ_PACKAGE_SHA)"
  package_paths_expr="$(yaml_env_ref YQ_PACKAGE_PATHS)"
  query=".packages += [{\"name\": ${package_name_expr}, \"source\": ${source_name_expr}, \"source_repo\": ${source_repo_expr}, \"source_path\": ${source_path_expr}, \"type\": ${package_type_expr}, \"sha\": ${package_sha_expr}, \"paths\": (${package_paths_expr} | fromjson)}]"
  YQ_PACKAGE_NAME="$pkg" YQ_SOURCE_NAME="$source" YQ_PACKAGE_TYPE="$type" \
    YQ_PACKAGE_SHA="$sha" YQ_SOURCE_REPO="$source_repo" YQ_SOURCE_PATH="$source_path" \
    YQ_PACKAGE_PATHS="$paths_json" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$tmp"

  mv "$tmp" "$file"
}

yaml_lock_remove_entry() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 0
  local package_name_expr query
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  query=".packages |= map(select(.name != ${package_name_expr}))"
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$file"
}

yaml_lock_mark_forked() {
  local file="$1"
  local pkg="$2"
  require_yq
  [ -f "$file" ] || return 1
  local package_name_expr query
  package_name_expr="$(yaml_env_ref YQ_PACKAGE_NAME)"
  query=".packages |= map((select(.name == ${package_name_expr}) | . + {\"forked\": true}) // .)"
  YQ_PACKAGE_NAME="$pkg" "$YQ_BIN" "${YQ_OUTPUT_ARGS[@]}" -i "$query" "$file"
}
