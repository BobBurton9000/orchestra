#!/bin/bash

set -euo pipefail

GH_BIN="${GH_BIN:-gh}"

gh_check_auth() {
  if ! command -v "$GH_BIN" >/dev/null 2>&1; then
    die "GitHub CLI ('$GH_BIN') not found on PATH. Install it from https://cli.github.com and run 'gh auth login'."
  fi
  if ! "$GH_BIN" auth status >/dev/null 2>&1; then
    die "GitHub CLI is not authenticated. Run 'gh auth login' first."
  fi
}

gh_default_branch() {
  local owner_repo="$1"
  "$GH_BIN" api "repos/${owner_repo}" --jq '.default_branch' 2>/dev/null | tr -d '\r\n'
}

gh_head_sha() {
  local owner_repo="$1"
  local ref="${2:-}"
  local ref_path
  if [ -n "$ref" ]; then
    ref_path="commits/${ref}"
  else
    local branch
    branch="$(gh_default_branch "$owner_repo")"
    ref_path="commits/${branch}"
  fi
  "$GH_BIN" api "repos/${owner_repo}/${ref_path}" --jq '.sha' 2>/dev/null | tr -d '\r\n'
}

gh_fetch_file_raw() {
  local owner_repo="$1"
  local path="$2"
  local ref="${3:-}"
  local query=""
  [ -n "$ref" ] && query="?ref=${ref}"
  "$GH_BIN" api -H "Accept: application/vnd.github.raw+json" \
    "repos/${owner_repo}/contents/${path}${query}" 2>/dev/null
}

gh_list_dir() {
  local owner_repo="$1"
  local path="$2"
  local ref="${3:-}"
  local query=""
  [ -n "$ref" ] && query="?ref=${ref}"
  "$GH_BIN" api "repos/${owner_repo}/contents/${path}${query}" --jq '.[].name' 2>/dev/null | tr -d '\r'
}

gh_fetch_manifest() {
  local owner_repo="$1"
  local ref="${2:-}"
  gh_fetch_file_raw "$owner_repo" "orchestra-source.yaml" "$ref"
}

gh_repo_push_permission() {
  local owner_repo="$1"
  "$GH_BIN" api "repos/${owner_repo}" --jq '.permissions.push // false' 2>/dev/null | tr -d '\r\n'
}

gh_clone_repo() {
  local owner_repo="$1"
  local destination="$2"
  "$GH_BIN" repo clone "$owner_repo" "$destination"
}

gh_create_pull_request() {
  local owner_repo="$1"
  local head="$2"
  local base="$3"
  local title="$4"
  local body="$5"
  "$GH_BIN" pr create --repo "$owner_repo" --head "$head" --base "$base" --title "$title" --body "$body"
}
