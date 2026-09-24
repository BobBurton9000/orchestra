#!/bin/bash
# gh stub shim for Orchestra tests.
# Intercepts `gh api` calls and returns fixture content so tests don't hit real GitHub.
#
# Recognises:
#   gh api repos/{owner}/{repo}                          -> .default_branch = "main"
#   gh api repos/{owner}/{repo}/commits/{ref}            -> .sha = $FIXTURE_SHA
#   gh api repos/{owner}/{repo}/contents/{path}?ref={ref}  -> raw file content (if --jq '.[].name' -> dir listing)
#
# The fixture source tree lives at $FIXTURE_SOURCE_DIR.

set -eo pipefail

if [ "${1:-}" = "repo" ] && [ "${2:-}" = "clone" ]; then
  destination="${4:-}"
  [ -n "${GH_STUB_REPO_DIR:-}" ] || {
    echo "gh stub: GH_STUB_REPO_DIR is required for repo clone" >&2
    exit 1
  }
  [ -n "$destination" ] || {
    echo "gh stub: repo clone destination is required" >&2
    exit 1
  }
  git clone --quiet "$GH_STUB_REPO_DIR" "$destination"
  exit 0
fi

if [ "${1:-}" = "pr" ] && [ "${2:-}" = "create" ]; then
  echo "${GH_STUB_PR_URL:-https://github.com/test/source/pull/1}"
  exit 0
fi

if [ "${1:-}" = "auth" ]; then
  if [ "${2:-}" = "status" ]; then
    echo "github.com"
    echo "  ✓ Logged in to github.com account test (keyring)"
    echo "  - Active account: true"
    echo "  - Token: gho_test************************************"
    exit 0
  fi
  exit 0
fi

if [ "${1:-}" != "api" ]; then
  echo "gh stub: only 'api' subcommand is supported (got: ${1:-})" >&2
  exit 1
fi

shift

# Parse arguments: collect flags, find the URL positional argument
url=""
jq_filter=""
while [ $# -gt 0 ]; do
  case "$1" in
    -H)
      shift 2 || true
      ;;
    --jq)
      jq_filter="$2"
      shift 2 || true
      ;;
    -F)
      shift 2 || true
      ;;
    --*)
      shift 2 || true
      ;;
    -*)
      shift
      ;;
    *)
      if [ -z "$url" ]; then
        url="$1"
      fi
      shift
      ;;
  esac
done

FIXTURE_SOURCE_DIR="${FIXTURE_SOURCE_DIR:?FIXTURE_SOURCE_DIR must be set}"
FIXTURE_SHA="${FIXTURE_SHA:-abc123def456789012345678901234567890abcd}"

# Parse the URL: repos/{owner}/{repo}[/commits/{ref}|/contents/{path}][?ref={ref}]
url="${url#repos/}"

# Extract query string if present
query=""
if [[ "$url" == *"?"* ]]; then
  query="${url#*\?}"
  url="${url%%\?*}"
fi

# Extract ref from query
ref=""
if [[ "$query" == *"ref="* ]]; then
  ref="${query#*ref=}"
  ref="${ref%%&*}"
fi

# Split remaining path
# owner/repo is the first two segments
owner_repo="${url%%/*}"          # test
url_rest="${url#*/}"             # source/contents/skills/demo-skill
owner_repo="$owner_repo/${url_rest%%/*}"   # test/source
rest="${url_rest#*/}"            # contents/skills/demo-skill
if [ "$rest" = "$url_rest" ]; then
  rest=""
fi

# Handle: repos/{owner}/{repo}  (no rest)  -> repo metadata
if [ -z "$rest" ]; then
  if [ "$jq_filter" = ".default_branch" ]; then
    echo "main"
    exit 0
  fi
  if [ "$jq_filter" = ".permissions.push // false" ]; then
    echo "${GH_STUB_PUSH_PERMISSION:-true}"
    exit 0
  fi
  echo "{\"default_branch\":\"main\",\"permissions\":{\"push\":${GH_STUB_PUSH_PERMISSION:-true}}}"
  exit 0
fi

# Handle: repos/{owner}/{repo}/commits/{ref}  -> commit metadata
if [[ "$rest" == commits/* ]]; then
  if [ "$jq_filter" = ".sha" ]; then
    echo "$FIXTURE_SHA"
    exit 0
  fi
  echo "{\"sha\":\"$FIXTURE_SHA\"}"
  exit 0
fi

# Handle: repos/{owner}/{repo}/contents/{path}  -> file or dir listing
if [[ "$rest" == contents/* ]]; then
  path="${rest#contents/}"
  path="${path#/}"

  if [ "$jq_filter" = ".[].name" ]; then
    target="$FIXTURE_SOURCE_DIR/$path"
    if [ -d "$target" ]; then
      for f in "$target"/*; do
        [ -e "$f" ] || continue
        basename "$f"
      done
    fi
    exit 0
  fi

  target="$FIXTURE_SOURCE_DIR/$path"
  if [ -f "$target" ]; then
    cat "$target"
    exit 0
  fi

  echo "gh stub: file not found: $target" >&2
  exit 1
fi

echo "gh stub: unrecognised URL: $url" >&2
exit 1