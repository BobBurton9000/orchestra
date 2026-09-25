#!/bin/bash
# Orchestra test suite — runs all tests against fixture content via a gh stub shim.
# Usage: bash tests/run-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TESTS_DIR="$SCRIPT_DIR"

FIXTURE_SOURCE_DIR="$TESTS_DIR/fixtures/source"
FIXTURE_SOURCE_V2_DIR="$TESTS_DIR/fixtures/source-v2"
FIXTURE_SHA="abc123def456789012345678901234567890abcd"

export FIXTURE_SOURCE_DIR
export FIXTURE_SHA

GH_STUB="$TESTS_DIR/helpers/gh-stub.sh"

PASS=0
FAIL=0
FAILURES=()

if ! command -v yq >/dev/null 2>&1; then
  echo "yq not found on PATH. Install it (mikefarah/yq or kislyuk/yq) and re-run." >&2
  exit 1
fi

setup_test_project() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.orchestra"
  cp "$REPO_ROOT/orchestra.sh" "$tmp/.orchestra/orchestra.sh"
  cp "$REPO_ROOT/orchestra-manifest.sh" "$tmp/.orchestra/orchestra-manifest.sh"
  chmod +x "$tmp/.orchestra/orchestra-manifest.sh"
  cp -r "$REPO_ROOT/scripts" "$tmp/.orchestra/scripts"
  cp -r "$REPO_ROOT/completion" "$tmp/.orchestra/completion" 2>/dev/null || mkdir -p "$tmp/.orchestra/completion"
  # Set up the gh stub on PATH
  mkdir -p "$tmp/bin"
  cp "$GH_STUB" "$tmp/bin/gh"
  chmod +x "$tmp/bin/gh"
  echo "$tmp"
}

teardown_test_project() {
  local tmp="$1"
  rm -rf "$tmp"
}

test_gitignore_for_project_state() {
  local tmp
  tmp="$(mktemp -d)"
  mkdir -p "$tmp/.orchestra"
  cp "$REPO_ROOT/.gitignore" "$tmp/.orchestra/.gitignore"
  git -C "$tmp" init -q

  local path
  for path in \
    .orchestra/sources.yaml \
    .orchestra/pkg.lock.yaml \
    .orchestra/pkg-cache/head.sha \
    .orchestra/config.yml \
    .orchestra/.temp/file; do
    mkdir -p "$(dirname "$tmp/$path")"
    : > "$tmp/$path"
    if ! git -C "$tmp" check-ignore -q "$path"; then
      FAIL=$((FAIL + 1))
      FAILURES+=("FAIL: $path is not ignored")
      continue
    fi
    PASS=$((PASS + 1))
  done

  teardown_test_project "$tmp"
}

run_in_project() {
  local tmp="$1"
  shift
  (
    unset ORCHESTRA_PROJECT_ROOT
    cd "$tmp"
    PATH="$tmp/bin:$PATH" \
      ORCHESTRA_YES="${ORCHESTRA_YES:-}" \
      FIXTURE_SOURCE_DIR="$FIXTURE_SOURCE_DIR" \
      FIXTURE_SHA="$FIXTURE_SHA" \
      GH_STUB_REPO_DIR="${GH_STUB_REPO_DIR:-}" \
      GH_STUB_PUSH_PERMISSION="${GH_STUB_PUSH_PERMISSION:-true}" \
      GH_STUB_PR_URL="${GH_STUB_PR_URL:-}" \
      .orchestra/orchestra.sh "$@"
  )
}

run_in_nested_project() {
  local tmp="$1"
  shift
  mkdir -p "$tmp/nested/work"
  (
    unset ORCHESTRA_PROJECT_ROOT
    cd "$tmp/nested/work"
    PATH="$tmp/bin:$PATH" \
      ORCHESTRA_YES="${ORCHESTRA_YES:-}" \
      FIXTURE_SOURCE_DIR="$FIXTURE_SOURCE_DIR" \
      FIXTURE_SHA="$FIXTURE_SHA" \
      GH_STUB_REPO_DIR="${GH_STUB_REPO_DIR:-}" \
      GH_STUB_PUSH_PERMISSION="${GH_STUB_PUSH_PERMISSION:-true}" \
      GH_STUB_PR_URL="${GH_STUB_PR_URL:-}" \
      "$tmp/.orchestra/orchestra.sh" "$@"
  )
}

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: $msg -- expected [$expected], got [$actual]")
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" msg="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: $msg -- expected [$needle] in output")
  fi
}

assert_file_exists() {
  local file="$1" msg="$2"
  if [ -f "$file" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: $msg -- file missing: $file")
  fi
}

assert_file_missing() {
  local file="$1" msg="$2"
  if [ ! -f "$file" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: $msg -- file still exists: $file")
  fi
}

assert_dir_exists() {
  local dir="$1" msg="$2"
  if [ -d "$dir" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: $msg -- dir missing: $dir")
  fi
}

assert_dir_missing() {
  local dir="$1" msg="$2"
  if [ ! -d "$dir" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: $msg -- dir still exists: $dir")
  fi
}

# Pre-configured sources.yaml pointing to a fixture source.
# We override the source name "core" to point to a fake repo "test/source"
# so the gh stub intercepts it.
write_test_sources_list() {
  local tmp="$1"
  cat > "$tmp/.orchestra/sources.yaml" <<EOF
sources:
  - name: core
    repo: test/source
EOF
}

setup_cached_source() {
  local tmp="$1"
  write_test_sources_list "$tmp"
  mkdir -p "$tmp/.orchestra/pkg-cache/core"
  echo "$FIXTURE_SHA" > "$tmp/.orchestra/pkg-cache/core/head.sha"
  echo "main" > "$tmp/.orchestra/pkg-cache/core/branch"
  cp "$FIXTURE_SOURCE_DIR/orchestra-source.yaml" "$tmp/.orchestra/pkg-cache/core/manifest.yaml"
}

setup_push_repository() {
  local tmp="$1"
  local source_checkout="$tmp/push-source"
  local remote="$tmp/push-source.git"

  git init --bare -q "$remote"
  mkdir -p "$source_checkout"
  cp -R "$FIXTURE_SOURCE_DIR/." "$source_checkout/"
  git -C "$source_checkout" init -q
  git -C "$source_checkout" config user.name "Orchestra Test"
  git -C "$source_checkout" config user.email "orchestra-test@example.com"
  git -C "$source_checkout" add -A
  git -C "$source_checkout" commit -qm "Initial source"
  git -C "$source_checkout" branch -M main
  git -C "$source_checkout" remote add origin "$remote"
  git -C "$source_checkout" push -q -u origin main
  git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

  GH_STUB_REPO_DIR="$remote"
  FIXTURE_SHA="$(git -C "$source_checkout" rev-parse HEAD)"
}

setup_test() {
  local tmp
  tmp="$(setup_test_project)"
  echo "$tmp"
}

# ---------------------------------------------------------------------------
# Test: help and version
# ---------------------------------------------------------------------------
test_help_version() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  local out
  out="$(run_in_project "$tmp" --version)"
  assert_eq "$out" "orchestra 1.0.0" "version output"

  out="$(run_in_project "$tmp" help)"
  assert_contains "$out" "install" "help mentions install"
  assert_contains "$out" "export copilot|opencode|pi" "help lists Pi export"
  assert_contains "$out" "convert" "help mentions convert"
  assert_contains "$out" "generate-manifest" "help mentions generate-manifest"
  assert_contains "$out" "status" "help mentions status"
  assert_contains "$out" "subscribe" "help mentions source subscriptions"
  assert_contains "$out" "fork" "help mentions fork"
  assert_contains "$out" "push" "help mentions push"
}

# ---------------------------------------------------------------------------
# Test: project root is discovered from a nested working directory
# ---------------------------------------------------------------------------
test_nested_project_directory() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  ORCHESTRA_YES=1 run_in_nested_project "$tmp" install demo-prompt >/dev/null 2>&1
  assert_file_exists "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md" "nested directory uses project root"
  assert_file_exists "$tmp/.orchestra/pkg.lock.yaml" "nested directory writes lockfile to project root"
}

# ---------------------------------------------------------------------------
# Test: completion resolves state from a nested working directory
# ---------------------------------------------------------------------------
test_completion_from_nested_directory() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf '%s\n' 'packages:' '  - name: demo-agent' > "$tmp/.orchestra/pkg.lock.yaml"
  mkdir -p "$tmp/nested/work"

  local out
  out="$(
    cd "$tmp/nested/work"
    unset ORCHESTRA_PROJECT_ROOT ORCHESTRA_DIR
    _init_completion() {
      cur="${COMP_WORDS[COMP_CWORD]}"
      prev="${COMP_WORDS[COMP_CWORD-1]:-}"
      words=("${COMP_WORDS[@]}")
      cword="$COMP_CWORD"
    }
    source "$tmp/.orchestra/completion/orchestra-completion.bash"

    COMP_WORDS=(orchestra install "")
    COMP_CWORD=2
    _orchestra_completion
    printf '%s\n' "${COMPREPLY[@]}"

    COMP_WORDS=(orchestra source subscribe "")
    COMP_CWORD=3
    COMPREPLY=()
    _orchestra_completion
    printf '%s\n' "${COMPREPLY[@]}"

    COMP_WORDS=(orchestra fork "")
    COMP_CWORD=2
    COMPREPLY=()
    _orchestra_completion
    printf '%s\n' "${COMPREPLY[@]}"

    COMP_WORDS=(orchestra push "")
    COMP_CWORD=2
    COMPREPLY=()
    _orchestra_completion
    printf '%s\n' "${COMPREPLY[@]}"

    COMP_WORDS=(orchestra push demo-agent "--")
    COMP_CWORD=3
    COMPREPLY=()
    _orchestra_completion
    printf '%s\n' "${COMPREPLY[@]}"

    COMP_WORDS=(orchestra export p)
    COMP_CWORD=2
    COMPREPLY=()
    _orchestra_completion
    printf '%s\n' "${COMPREPLY[@]}"

    COMP_WORDS=(orchestra convert p)
    COMP_CWORD=2
    COMPREPLY=()
    _orchestra_completion
    printf 'convert:%s\n' "${COMPREPLY[@]}"
  )"

  assert_contains "$out" "demo-agent" "completion finds packages from nested directory"
  assert_contains "$out" "--dry-run" "completion finds push flags"
  assert_contains "$out" "pi" "export completion offers Pi"
  if [[ "$out" == *"convert:pi"* ]]; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: convert completion unexpectedly offers Pi")
  else
    PASS=$((PASS + 1))
  fi
  assert_contains "$out" "core" "completion finds sources from nested directory"
}

# ---------------------------------------------------------------------------
# Test: source list auto-creates default sources.yaml
# ---------------------------------------------------------------------------
test_source_list_default() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  local out
  out="$(run_in_project "$tmp" source list 2>&1)"
  assert_contains "$out" "core" "default source list mentions core"
  assert_contains "$out" "BobBurton9000/orchestra-defaults" "default source list mentions defaults repo"
  assert_file_exists "$tmp/.orchestra/sources.yaml" "sources.yaml auto-created"
}

# ---------------------------------------------------------------------------
# Test: generate-manifest on fixture source
# ---------------------------------------------------------------------------
test_generate_manifest() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  local source="$tmp/source"
  mkdir -p "$source"
  cp -R "$FIXTURE_SOURCE_DIR/agents" "$source/agents"
  cp -R "$FIXTURE_SOURCE_DIR/prompts" "$source/prompts"
  cp -R "$FIXTURE_SOURCE_DIR/skills" "$source/skills"

  ORCHESTRA_YES=1 run_in_project "$tmp" generate-manifest "$source" >/dev/null 2>&1
  local manifest="$source/orchestra-source.yaml"
  assert_file_exists "$manifest" "generate-manifest creates orchestra-source.yaml"

  local content
  content="$(cat "$manifest")"
  assert_contains "$content" "name: demo-agent" "manifest has demo-agent"
  assert_contains "$content" "type: agent" "manifest has agent type"
  assert_contains "$content" "name: demo-skill" "manifest has demo-skill"
  assert_contains "$content" "type: skill" "manifest has skill type"
  assert_contains "$content" "name: snippets" "manifest has snippets prompt-dir"
  assert_contains "$content" "type: prompt-dir" "manifest has prompt-dir type"
}

# ---------------------------------------------------------------------------
# Test: standalone manifest tool works without an Orchestra project
# ---------------------------------------------------------------------------
test_standalone_manifest() {
  local tmp source
  tmp="$(mktemp -d)"
  source="$tmp/source"
  trap "rm -rf '$tmp'" RETURN

  mkdir -p "$source"
  cp -R "$FIXTURE_SOURCE_DIR/agents" "$source/agents"
  cp -R "$FIXTURE_SOURCE_DIR/prompts" "$source/prompts"
  cp -R "$FIXTURE_SOURCE_DIR/skills" "$source/skills"

  "$REPO_ROOT/orchestra-manifest.sh" --force "$source" >/dev/null 2>&1
  assert_file_exists "$source/orchestra-source.yaml" "standalone tool creates manifest"

  local package_count
  package_count="$(yq -r '.packages | length' "$source/orchestra-source.yaml")"
  assert_eq "$package_count" "5" "standalone manifest package count"

  local out rc=0
  out="$("$REPO_ROOT/orchestra-manifest.sh" --check "$source" 2>&1)" || rc=$?
  assert_eq "$rc" "0" "standalone check accepts current manifest"
  assert_contains "$out" "up to date" "standalone check reports current manifest"

  cp "$FIXTURE_SOURCE_DIR/agents/second-agent.agent.md" "$source/agents/new-agent.agent.md"
  out="$("$REPO_ROOT/orchestra-manifest.sh" --check "$source" 2>&1)" || rc=$?
  assert_eq "$rc" "1" "standalone check rejects stale manifest"
  assert_contains "$out" "out of date" "standalone check reports stale manifest"
}

# ---------------------------------------------------------------------------
# Test: standalone manifest tool updates itself from a remote copy
# ---------------------------------------------------------------------------
test_standalone_self_update() {
  local tmp source
  tmp="$(mktemp -d)"
  source="$tmp/source"
  trap "rm -rf '$tmp'" RETURN

  mkdir -p "$source"
  cp -R "$FIXTURE_SOURCE_DIR/agents" "$source/agents"
  cp -R "$FIXTURE_SOURCE_DIR/prompts" "$source/prompts"
  cp -R "$FIXTURE_SOURCE_DIR/skills" "$source/skills"
  cp "$REPO_ROOT/orchestra-manifest.sh" "$tmp/orchestra-manifest.sh"
  chmod +x "$tmp/orchestra-manifest.sh"

  ORCHESTRA_MANIFEST_URL="file://$REPO_ROOT/orchestra-manifest.sh" \
    "$tmp/orchestra-manifest.sh" --self-update --force "$source" >/dev/null 2>&1

  assert_file_exists "$source/orchestra-source.yaml" "self-updating tool generates manifest"
  assert_file_exists "$tmp/orchestra-manifest.sh" "self-updating tool remains installed"
}

# ---------------------------------------------------------------------------
# Test: install single agent (with config.yml pre-set for silent model)
# ---------------------------------------------------------------------------
test_install_agent_silent_model() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  assert_file_exists "$tmp/.agents/orchestra/agents/demo-agent.agent.md" "agent file installed"
  assert_file_exists "$tmp/.orchestra/pkg.lock.yaml" "lockfile created"

  local model
  model="$(grep '^model:' "$tmp/.agents/orchestra/agents/demo-agent.agent.md" | tr -d '\r')"
  assert_eq "$model" "model: claude-sonnet" "agent model written silently from config.yml"

  local lock_source lock_type lock_sha
  lock_source="$(yq -r '.packages[] | select(.name=="demo-agent") | .source' "$tmp/.orchestra/pkg.lock.yaml")"
  lock_type="$(yq -r '.packages[] | select(.name=="demo-agent") | .type' "$tmp/.orchestra/pkg.lock.yaml")"
  lock_sha="$(yq -r '.packages[] | select(.name=="demo-agent") | .sha' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$lock_source" "core" "lockfile has source"
  assert_eq "$lock_type" "agent" "lockfile has type"
  assert_eq "$lock_sha" "$FIXTURE_SHA" "lockfile has SHA"
}

# ---------------------------------------------------------------------------
# Test: install prompt
# ---------------------------------------------------------------------------
test_install_prompt() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  run_in_project "$tmp" install demo-prompt >/dev/null 2>&1

  assert_file_exists "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md" "prompt file installed"
}

# ---------------------------------------------------------------------------
# Test: install skill (multi-file)
# ---------------------------------------------------------------------------
test_install_skill_multifile() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  assert_file_exists "$tmp/.agents/orchestra/skills/demo-skill/SKILL.md" "skill SKILL.md installed"
  assert_file_exists "$tmp/.agents/orchestra/skills/demo-skill/helper.md" "skill helper.md installed"

  local lock_paths
  lock_paths="$(yq -r '.packages[] | select(.name=="demo-skill") | .paths | join("|")' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$lock_paths" "skills/demo-skill/SKILL.md|skills/demo-skill/helper.md" "lockfile records both skill files"
}

# ---------------------------------------------------------------------------
# Test: install prompt-dir (snippets)
# ---------------------------------------------------------------------------
test_install_prompt_dir() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  run_in_project "$tmp" install snippets >/dev/null 2>&1

  assert_file_exists "$tmp/.agents/orchestra/prompts/snippets/branch-name.md" "snippet file installed"
}

# ---------------------------------------------------------------------------
# Test: install --all <source>
# ---------------------------------------------------------------------------
test_install_all() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  write_test_sources_list "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install --all core >/dev/null 2>&1

  assert_file_exists "$tmp/.agents/orchestra/agents/demo-agent.agent.md" "install --all: demo-agent"
  assert_file_exists "$tmp/.agents/orchestra/agents/second-agent.agent.md" "install --all: second-agent"
  assert_file_exists "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md" "install --all: demo-prompt"
  assert_file_exists "$tmp/.agents/orchestra/prompts/snippets/branch-name.md" "install --all: snippets"
  assert_file_exists "$tmp/.agents/orchestra/skills/demo-skill/SKILL.md" "install --all: demo-skill"

  local count
  count="$(yq -r '.packages | length' "$tmp/.orchestra/pkg.lock.yaml" 2>/dev/null)"
  assert_eq "$count" "5" "install --all locks 5 packages"
}

# ---------------------------------------------------------------------------
# Test: list installed
# ---------------------------------------------------------------------------
test_list_installed() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" list)"
  assert_contains "$out" "demo-agent" "list shows demo-agent"
  assert_contains "$out" "demo-skill" "list shows demo-skill"
  assert_contains "$out" "Total: 2" "list shows correct total"
}

# ---------------------------------------------------------------------------
# Test: search
# ---------------------------------------------------------------------------
test_search() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  local out
  out="$(run_in_project "$tmp" search agent)"
  assert_contains "$out" "demo-agent" "search finds demo-agent"
  assert_contains "$out" "second-agent" "search finds second-agent"
}

# ---------------------------------------------------------------------------
# Test: info on installed package
# ---------------------------------------------------------------------------
test_info_installed() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" info demo-agent 2>&1)"
  assert_contains "$out" "installed" "info shows installed status"
  assert_contains "$out" "core" "info shows source"
  assert_contains "$out" "agent" "info shows type"
}

# ---------------------------------------------------------------------------
# Test: info on available (not installed) package
# ---------------------------------------------------------------------------
test_info_available() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"

  local out
  out="$(run_in_project "$tmp" info demo-agent 2>&1)"
  assert_contains "$out" "available" "info shows available status"
  assert_contains "$out" "not installed" "info says not installed"
}

# ---------------------------------------------------------------------------
# Test: status reports package paths that exist on disk
# ---------------------------------------------------------------------------
test_status_reports_managed_paths() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" status)"
  assert_contains "$out" "[OK] demo-agent" "status reports agent package as healthy"
  assert_contains "$out" "[TRACKED] .agents/orchestra/agents/demo-agent.agent.md" "status reports tracked agent path"
  assert_contains "$out" "[TRACKED] .agents/orchestra/skills/demo-skill/SKILL.md" "status reports tracked skill entrypoint"
  assert_contains "$out" "[TRACKED] .agents/orchestra/skills/demo-skill/helper.md" "status reports tracked skill companion"
  assert_contains "$out" "Summary: 2 package(s), 3 managed file(s), 0 missing file(s), 0 file(s) not part of a package." "status reports clean summary"
}

# ---------------------------------------------------------------------------
# Test: status reports missing lockfile paths and orphaned files
# ---------------------------------------------------------------------------
test_status_reports_missing_and_untracked() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  rm -f "$tmp/.agents/orchestra/agents/demo-agent.agent.md"
  printf '%s\n' '---' 'name: local-agent' '---' > "$tmp/.agents/orchestra/agents/local-agent.agent.md"

  local out
  out="$(run_in_project "$tmp" status)"
  assert_contains "$out" "[MISSING] demo-agent" "status marks package with missing path"
  assert_contains "$out" "[MISSING] .agents/orchestra/agents/demo-agent.agent.md" "status reports missing path"
  assert_contains "$out" "[UNTRACKED] .agents/orchestra/agents/local-agent.agent.md" "status reports orphaned file"
  assert_contains "$out" "Summary: 1 package(s), 1 managed file(s), 1 missing file(s), 1 file(s) not part of a package." "status reports inconsistency summary"
}

# ---------------------------------------------------------------------------
# Test: status works without a lockfile and finds local files
# ---------------------------------------------------------------------------
test_status_without_lockfile() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  mkdir -p "$tmp/.agents/orchestra/prompts"
  printf '%s\n' '# Local prompt' > "$tmp/.agents/orchestra/prompts/local.md"

  local out
  out="$(run_in_project "$tmp" status)"
  assert_contains "$out" "Installed packages: none (no lockfile)" "status handles missing lockfile"
  assert_contains "$out" "[UNTRACKED] .agents/orchestra/prompts/local.md" "status finds file without lockfile"
  assert_contains "$out" "Summary: 0 package(s), 0 managed file(s), 0 missing file(s), 1 file(s) not part of a package." "status reports no-lockfile summary"
}

# ---------------------------------------------------------------------------
# Test: remove deletes files and lockfile entry
# ---------------------------------------------------------------------------
test_remove() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1
  assert_file_exists "$tmp/.agents/orchestra/skills/demo-skill/SKILL.md" "precondition: skill installed"

  ORCHESTRA_YES=1 run_in_project "$tmp" remove demo-skill >/dev/null 2>&1
  assert_file_missing "$tmp/.agents/orchestra/skills/demo-skill/SKILL.md" "remove deletes SKILL.md"
  assert_file_missing "$tmp/.agents/orchestra/skills/demo-skill/helper.md" "remove deletes helper.md"
  assert_dir_missing "$tmp/.agents/orchestra/skills/demo-skill" "remove cleans up skill dir"

  if yq -e '.packages[] | select(.name=="demo-skill")' "$tmp/.orchestra/pkg.lock.yaml" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: remove -- lockfile still contains demo-skill")
  else
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test: remove reconciles a lockfile entry when its file is already missing
# ---------------------------------------------------------------------------
test_remove_missing_file() {
  local tmp out
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  cat > "$tmp/.orchestra/pkg.lock.yaml" <<'EOF'
packages:
  - name: stale-agent
    source: core
    type: agent
    sha: abc123def456789012345678901234567890abcd
    paths:
      - agents/stale-agent.agent.md
EOF

  out="$(ORCHESTRA_YES=1 run_in_project "$tmp" remove stale-agent 2>&1)"
  assert_contains "$out" "Removed 'stale-agent' from source 'core' (0 file(s) deleted, 1 already absent)." "remove reports an already-missing package file"

  if yq -e '.packages[] | select(.name=="stale-agent")' "$tmp/.orchestra/pkg.lock.yaml" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: remove -- stale-agent remains in lockfile")
  else
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test: fork detaches agent, prompt, and skill packages from upgrades
# ---------------------------------------------------------------------------
test_fork_detaches_packages() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  printf '\nLocal agent fork.\n' >> "$tmp/.agents/orchestra/agents/demo-agent.agent.md"
  printf '\nLocal prompt fork.\n' >> "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md"
  printf '\nLocal skill fork.\n' >> "$tmp/.agents/orchestra/skills/demo-skill/helper.md"

  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-prompt >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-skill >/dev/null 2>&1

  local forked_count
  forked_count="$(yq -r '[.packages[] | select(.forked == true)] | length' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$forked_count" "3" "fork marks all package types in the lockfile"

  local new_sha="forked999forked999forked999forked999forked"
  echo "$new_sha" > "$tmp/.orchestra/pkg-cache/core/head.sha"

  local targeted_out targeted_rc=0
  targeted_out="$(run_in_project "$tmp" upgrade demo-agent 2>&1)" || targeted_rc=$?
  assert_eq "$targeted_rc" "0" "targeted upgrade treats forked package as unchanged"
  assert_contains "$targeted_out" "demo-agent is forked" "targeted upgrade skips forked agent"

  local out
  out="$(ORCHESTRA_YES=1 run_in_project "$tmp" upgrade 2>&1)"
  assert_contains "$out" "demo-agent is forked" "bulk upgrade skips forked agent"
  assert_contains "$out" "demo-prompt is forked" "bulk upgrade skips forked prompt"
  assert_contains "$out" "demo-skill is forked" "bulk upgrade skips forked skill"
  assert_contains "$(cat "$tmp/.agents/orchestra/agents/demo-agent.agent.md")" "Local agent fork." "fork preserves agent edits"
  assert_contains "$(cat "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md")" "Local prompt fork." "fork preserves prompt edits"
  assert_contains "$(cat "$tmp/.agents/orchestra/skills/demo-skill/helper.md")" "Local skill fork." "fork preserves skill edits"

  local info list status
  info="$(run_in_project "$tmp" info demo-agent 2>&1)"
  assert_contains "$info" "Status:    forked" "info reports forked package"
  assert_contains "$info" "Upgrade:   disabled" "info disables forked upgrades"
  list="$(run_in_project "$tmp" list)"
  assert_contains "$list" "demo-agent" "list retains forked package"
  assert_contains "$list" "(forked)" "list identifies forked package"
  status="$(run_in_project "$tmp" status)"
  assert_contains "$status" "demo-skill (skill, core (forked)" "status identifies forked package"
}

test_push_agent_pull_request() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  local repo_before="${GH_STUB_REPO_DIR:-}"
  local permission_before="${GH_STUB_PUSH_PERMISSION:-true}"
  local pr_before="${GH_STUB_PR_URL:-}"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; GH_STUB_REPO_DIR="$repo_before"; GH_STUB_PUSH_PERMISSION="$permission_before"; GH_STUB_PR_URL="$pr_before"; teardown_test_project "$tmp"' RETURN

  setup_push_repository "$tmp"
  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  printf '\nLocal agent update.\n' >> "$tmp/.agents/orchestra/agents/demo-agent.agent.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-agent >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" push demo-agent --branch orchestra/test-agent 2>&1)"
  assert_contains "$out" "Pull request: https://github.com/test/source/pull/1" "push reports created pull request"

  local remote_agent
  remote_agent="$(git --git-dir="$GH_STUB_REPO_DIR" show orchestra/test-agent:agents/demo-agent.agent.md)"
  assert_contains "$remote_agent" "Local agent update." "push copies local agent edits to source branch"
  if printf '%s\n' "$remote_agent" | grep -q '^model:'; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: push agent -- source branch still contains injected model")
  else
    PASS=$((PASS + 1))
  fi

  assert_eq "$(yq -r '.packages[] | select(.name=="demo-agent") | .source_repo' "$tmp/.orchestra/pkg.lock.yaml")" "test/source" "lockfile records source repository"
  assert_eq "$(yq -r '.packages[] | select(.name=="demo-agent") | .source_path' "$tmp/.orchestra/pkg.lock.yaml")" "agents/demo-agent.agent.md" "lockfile records source path"
  assert_eq "$(yq -r '.packages[] | select(.name=="demo-agent") | (.forked // false)' "$tmp/.orchestra/pkg.lock.yaml")" "true" "pull request leaves package forked"
}

test_push_skill_pull_request() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  local repo_before="${GH_STUB_REPO_DIR:-}"
  local permission_before="${GH_STUB_PUSH_PERMISSION:-true}"
  local pr_before="${GH_STUB_PR_URL:-}"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; GH_STUB_REPO_DIR="$repo_before"; GH_STUB_PUSH_PERMISSION="$permission_before"; GH_STUB_PR_URL="$pr_before"; teardown_test_project "$tmp"' RETURN

  setup_push_repository "$tmp"
  setup_cached_source "$tmp"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1
  printf '\nLocal skill update.\n' >> "$tmp/.agents/orchestra/skills/demo-skill/helper.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-skill >/dev/null 2>&1

  run_in_project "$tmp" push demo-skill --branch orchestra/test-skill >/dev/null 2>&1

  local remote_helper remote_skill
  remote_helper="$(git --git-dir="$GH_STUB_REPO_DIR" show orchestra/test-skill:skills/demo-skill/helper.md)"
  remote_skill="$(git --git-dir="$GH_STUB_REPO_DIR" show orchestra/test-skill:skills/demo-skill/SKILL.md)"
  assert_contains "$remote_helper" "Local skill update." "push copies multi-file skill edits"
  assert_contains "$remote_skill" "Demo Skill" "push preserves the skill entrypoint"
}

test_push_direct_updates_lock() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  local repo_before="${GH_STUB_REPO_DIR:-}"
  local permission_before="${GH_STUB_PUSH_PERMISSION:-true}"
  local pr_before="${GH_STUB_PR_URL:-}"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; GH_STUB_REPO_DIR="$repo_before"; GH_STUB_PUSH_PERMISSION="$permission_before"; GH_STUB_PR_URL="$pr_before"; teardown_test_project "$tmp"' RETURN

  setup_push_repository "$tmp"
  setup_cached_source "$tmp"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  printf '\nLocal direct update.\n' >> "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-prompt >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" push demo-prompt --direct 2>&1)"
  assert_contains "$out" "Pushed 'demo-prompt' directly" "direct push reports success"

  local direct_sha locked_sha forked remote_prompt
  direct_sha="$(git --git-dir="$GH_STUB_REPO_DIR" rev-parse refs/heads/main)"
  locked_sha="$(yq -r '.packages[] | select(.name=="demo-prompt") | .sha' "$tmp/.orchestra/pkg.lock.yaml")"
  forked="$(yq -r '.packages[] | select(.name=="demo-prompt") | (.forked // false)' "$tmp/.orchestra/pkg.lock.yaml")"
  remote_prompt="$(git --git-dir="$GH_STUB_REPO_DIR" show main:prompts/demo-prompt.prompt.md)"
  assert_eq "$locked_sha" "$direct_sha" "direct push updates the lockfile SHA"
  assert_eq "$forked" "false" "direct push reattaches the package"
  assert_contains "$remote_prompt" "Local direct update." "direct push updates the default branch"
}

test_push_requires_source_permission() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  local repo_before="${GH_STUB_REPO_DIR:-}"
  local permission_before="${GH_STUB_PUSH_PERMISSION:-true}"
  local pr_before="${GH_STUB_PR_URL:-}"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; GH_STUB_REPO_DIR="$repo_before"; GH_STUB_PUSH_PERMISSION="$permission_before"; GH_STUB_PR_URL="$pr_before"; teardown_test_project "$tmp"' RETURN

  setup_push_repository "$tmp"
  setup_cached_source "$tmp"
  GH_STUB_PUSH_PERMISSION=false

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  printf '\nLocal permission test.\n' >> "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-prompt >/dev/null 2>&1

  local out rc=0
  out="$(run_in_project "$tmp" push demo-prompt 2>&1)" || rc=$?
  assert_eq "$rc" "1" "push without source permission exits non-zero"
  assert_contains "$out" "does not have push permission" "push explains missing source permission"
}

test_push_dry_run_does_not_publish() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  local repo_before="${GH_STUB_REPO_DIR:-}"
  local permission_before="${GH_STUB_PUSH_PERMISSION:-true}"
  local pr_before="${GH_STUB_PR_URL:-}"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; GH_STUB_REPO_DIR="$repo_before"; GH_STUB_PUSH_PERMISSION="$permission_before"; GH_STUB_PR_URL="$pr_before"; teardown_test_project "$tmp"' RETURN

  setup_push_repository "$tmp"
  setup_cached_source "$tmp"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  printf '\nLocal dry run.\n' >> "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-prompt >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" push demo-prompt --dry-run --branch orchestra/dry-run 2>&1)"
  assert_contains "$out" "Dry run for 'demo-prompt'" "dry run reports the package"
  assert_contains "$out" "Local dry run." "dry run shows the staged edit"
  if git --git-dir="$GH_STUB_REPO_DIR" show-ref --verify --quiet refs/heads/orchestra/dry-run; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: dry run -- remote branch was created")
  else
    PASS=$((PASS + 1))
  fi
}

test_push_rejects_source_conflict() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  local repo_before="${GH_STUB_REPO_DIR:-}"
  local permission_before="${GH_STUB_PUSH_PERMISSION:-true}"
  local pr_before="${GH_STUB_PR_URL:-}"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; GH_STUB_REPO_DIR="$repo_before"; GH_STUB_PUSH_PERMISSION="$permission_before"; GH_STUB_PR_URL="$pr_before"; teardown_test_project "$tmp"' RETURN

  setup_push_repository "$tmp"
  setup_cached_source "$tmp"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  printf '\nLocal conflict test.\n' >> "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-prompt >/dev/null 2>&1

  printf '\nRemote conflict.\n' >> "$tmp/push-source/prompts/demo-prompt.prompt.md"
  git -C "$tmp/push-source" add prompts/demo-prompt.prompt.md
  git -C "$tmp/push-source" commit -qm "Remote update"
  git -C "$tmp/push-source" push -q origin main
  FIXTURE_SHA="$(git -C "$tmp/push-source" rev-parse HEAD)"

  local out rc=0
  out="$(run_in_project "$tmp" push demo-prompt --branch orchestra/conflict 2>&1)" || rc=$?
  assert_eq "$rc" "1" "push with a source conflict exits non-zero"
  assert_contains "$out" "changed since package" "push explains source conflict"
}

# ---------------------------------------------------------------------------
# Test: forked packages can be removed and no longer block source removal
# ---------------------------------------------------------------------------
test_fork_remove_and_source_remove() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" fork demo-skill >/dev/null 2>&1

  run_in_project "$tmp" source remove core >/dev/null 2>&1
  assert_file_exists "$tmp/.agents/orchestra/skills/demo-skill/SKILL.md" "source removal keeps forked files"

  ORCHESTRA_YES=1 run_in_project "$tmp" remove demo-skill >/dev/null 2>&1
  assert_file_missing "$tmp/.agents/orchestra/skills/demo-skill/SKILL.md" "remove deletes forked files"
  if yq -e '.packages[] | select(.name=="demo-skill")' "$tmp/.orchestra/pkg.lock.yaml" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: remove forked package -- lockfile still contains demo-skill")
  else
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test: upgrade with SHA change
# ---------------------------------------------------------------------------
test_upgrade_sha_change() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  # Simulate a SHA change: bump the cached head.sha
  local new_sha="zzz999zzz999zzz999zzz999zzz999zzz999zzz9"
  echo "$new_sha" > "$tmp/.orchestra/pkg-cache/core/head.sha"

  ORCHESTRA_YES=1 run_in_project "$tmp" upgrade demo-agent >/dev/null 2>&1

  local locked_sha
  locked_sha="$(yq -r '.packages[] | select(.name=="demo-agent") | .sha' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$locked_sha" "$new_sha" "upgrade updates locked SHA"
}

# ---------------------------------------------------------------------------
# Test: upgrade reports up-to-date when SHA unchanged
# ---------------------------------------------------------------------------
test_upgrade_uptodate() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  local out
  out="$(run_in_project "$tmp" upgrade demo-agent 2>&1)"
  assert_contains "$out" "up to date" "upgrade reports up to date"
}

# ---------------------------------------------------------------------------
# Test: upgrade preserves the user's model choice
# ---------------------------------------------------------------------------
test_upgrade_preserves_model() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  local model_before
  model_before="$(grep '^model:' "$tmp/.agents/orchestra/agents/demo-agent.agent.md" | tr -d '\r')"
  assert_eq "$model_before" "model: claude-sonnet" "install injects model from config.yml"

  # Change config.yml so a re-resolution would pick gpt-4o
  printf 'orchestrator: gpt-4o\nsubagent: gpt-4o\n' > "$tmp/.orchestra/config.yml"

  # Bump the cached SHA to trigger an upgrade
  local new_sha="zzz999zzz999zzz999zzz999zzz999zzz999zzz9"
  echo "$new_sha" > "$tmp/.orchestra/pkg-cache/core/head.sha"

  ORCHESTRA_YES=1 run_in_project "$tmp" upgrade demo-agent >/dev/null 2>&1

  local model_after
  model_after="$(grep '^model:' "$tmp/.agents/orchestra/agents/demo-agent.agent.md" | tr -d '\r')"
  assert_eq "$model_after" "model: claude-sonnet" "upgrade preserves original model, ignores changed config.yml"
}

# ---------------------------------------------------------------------------
# Test: bulk upgrade over already-installed packages must not hang on
# overwrite prompts when stdin is not a TTY (regression: silent indefinite hang).
# ---------------------------------------------------------------------------
test_upgrade_bulk_overwrites_without_prompt() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  # Install several packages so the bulk loop has targets to overwrite.
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install second-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  # Bump the cached SHA so every package needs an upgrade.
  local new_sha="zzz999zzz999zzz999zzz999zzz999zzz999zzz9"
  echo "$new_sha" > "$tmp/.orchestra/pkg-cache/core/head.sha"

  # Bulk upgrade with a non-TTY stdin that never closes (simulates the original
  # hang scenario: script run under another process / CI with stdin piped).
  # Before the fix, the buried "Overwrite? [y/N]" prompt blocked on this stdin
  # forever. The watchdog ensures a regression fails fast instead of hanging
  # the whole suite.
  local out rc
  out="$(timeout 10 bash -c 'cd "'"$tmp"'" && PATH="'"$tmp"'/bin:$PATH" \
      FIXTURE_SOURCE_DIR="'"$FIXTURE_SOURCE_DIR"'" \
      FIXTURE_SHA="'"$FIXTURE_SHA"'" \
      .orchestra/orchestra.sh upgrade < <(sleep 30) 2>&1')" || rc=$?
  rc="${rc:-0}"
  assert_eq "$rc" "0" "bulk upgrade over installed packages exits 0 (no hang, no prompt)"
  assert_contains "$out" "Upgrade complete" "bulk upgrade reports completion"
  assert_contains "$out" "Upgrading demo-agent" "bulk upgrade streams per-package progress to stderr"

  # Every package should be locked at the new SHA — proves overwrite happened
  # without prompting (previously this hung before reaching lock_write_entry).
  local locked_sha
  locked_sha="$(yq -r '.packages[] | select(.name=="demo-agent") | .sha' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$locked_sha" "$new_sha" "bulk upgrade updated locked SHA"
}

# ---------------------------------------------------------------------------
# Test: subscribed sources install only packages added after subscription
# ---------------------------------------------------------------------------
test_source_subscribe_future_packages() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; teardown_test_project "$tmp"' RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  local out
  out="$(run_in_project "$tmp" source subscribe core 2>&1)"
  assert_contains "$out" "Subscribed to 'core'" "source subscribe reports subscription"

  local baseline_sha
  baseline_sha="$(yq -r '.sources[] | select(.name=="core") | .subscribed_since' "$tmp/.orchestra/sources.yaml")"
  assert_eq "$baseline_sha" "$FIXTURE_SHA" "subscription records baseline SHA"
  assert_file_exists "$tmp/.orchestra/pkg-cache/core/subscription-baseline.yaml" "subscription stores manifest baseline"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  local new_sha="new456new456new456new456new456new456new4"
  FIXTURE_SOURCE_DIR="$FIXTURE_SOURCE_V2_DIR"
  FIXTURE_SHA="$new_sha"

  ORCHESTRA_YES=1 out="$(run_in_project "$tmp" upgrade 2>&1)"
  assert_contains "$out" "Subscription sync complete" "upgrade reports subscription sync"
  assert_file_exists "$tmp/.agents/orchestra/agents/future-agent.agent.md" "subscription installs future agent"
  assert_file_exists "$tmp/.agents/orchestra/prompts/future-prompt.prompt.md" "subscription installs future prompt"
  assert_file_exists "$tmp/.agents/orchestra/prompts/future-snippets/context.md" "subscription installs future prompt-dir"
  assert_file_exists "$tmp/.agents/orchestra/skills/future-skill/SKILL.md" "subscription installs future skill"
  assert_file_exists "$tmp/.agents/orchestra/skills/future-skill/helper.md" "subscription installs future skill companion"

  assert_file_missing "$tmp/.agents/orchestra/agents/second-agent.agent.md" "subscription does not install baseline agent"
  assert_file_missing "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md" "subscription does not install baseline prompt"
  assert_dir_missing "$tmp/.agents/orchestra/prompts/snippets" "subscription does not install baseline prompt-dir"
  assert_dir_missing "$tmp/.agents/orchestra/skills/demo-skill" "subscription does not install baseline skill"

  local package_count
  package_count="$(yq -r '.packages | length' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$package_count" "5" "subscription locks explicit and future packages only"
  assert_eq "$(yq -r '.sources[] | select(.name=="core") | .subscribed_since' "$tmp/.orchestra/sources.yaml")" "$baseline_sha" "upgrade preserves subscription baseline"
}

# ---------------------------------------------------------------------------
# Test: unsubscribe stops future package installation
# ---------------------------------------------------------------------------
test_source_unsubscribe_stops_future_packages() {
  local tmp
  tmp="$(setup_test)"
  local fixture_source_before="$FIXTURE_SOURCE_DIR"
  local fixture_sha_before="$FIXTURE_SHA"
  trap 'FIXTURE_SOURCE_DIR="$fixture_source_before"; FIXTURE_SHA="$fixture_sha_before"; teardown_test_project "$tmp"' RETURN

  setup_cached_source "$tmp"
  run_in_project "$tmp" source subscribe core >/dev/null 2>&1
  run_in_project "$tmp" source unsubscribe core >/dev/null 2>&1

  local new_sha="new789new789new789new789new789new789new7"
  FIXTURE_SOURCE_DIR="$FIXTURE_SOURCE_V2_DIR"
  FIXTURE_SHA="$new_sha"

  ORCHESTRA_YES=1 run_in_project "$tmp" upgrade >/dev/null 2>&1
  assert_file_missing "$tmp/.agents/orchestra/agents/future-agent.agent.md" "unsubscribed source does not install future agent"
  if yq -e '.sources[] | select(.name == "core" and has("subscribed_since"))' "$tmp/.orchestra/sources.yaml" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: source unsubscribe -- subscription marker still present")
  else
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test: install injects model into source file without one
# ---------------------------------------------------------------------------
test_install_injects_model_into_source_without_one() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  local content
  content="$(cat "$tmp/.agents/orchestra/agents/demo-agent.agent.md")"
  assert_contains "$content" "model: claude-sonnet" "installed file has model injected from config.yml"

  local model_line
  model_line="$(grep '^model:' "$tmp/.agents/orchestra/agents/demo-agent.agent.md" | tr -d '\r')"
  assert_eq "$model_line" "model: claude-sonnet" "injected model matches config.yml subagent default"
}

# ---------------------------------------------------------------------------
# Test: source remove refuses when packages installed
# ---------------------------------------------------------------------------
test_source_remove_refuses() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1

  local out rc
  out="$(run_in_project "$tmp" source remove core 2>&1)" || rc=$?
  rc="${rc:-0}"
  assert_eq "$rc" "1" "source remove exits non-zero when packages installed"
  assert_contains "$out" "still installed" "source remove explains why it refused"
}

# ---------------------------------------------------------------------------
# Test: source remove succeeds when no packages installed
# ---------------------------------------------------------------------------
test_source_remove_succeeds() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  write_test_sources_list "$tmp"

  run_in_project "$tmp" source remove core >/dev/null 2>&1
  if yq -e '.sources[] | select(.name=="core")' "$tmp/.orchestra/sources.yaml" >/dev/null 2>&1; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: source remove -- core still in sources.yaml")
  else
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# Test: export opencode
# ---------------------------------------------------------------------------
test_export_opencode() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install snippets >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  mkdir -p "$tmp/.opencode/agents" "$tmp/.opencode/commands" "$tmp/.agents/skills/manual"
  : > "$tmp/.opencode/agents/stale.md"
  : > "$tmp/.opencode/agents/manual.md"
  : > "$tmp/.opencode/commands/manual.md"
  : > "$tmp/.agents/skills/manual/SKILL.md"
  run_in_project "$tmp" export opencode >/dev/null 2>&1

  assert_file_exists "$tmp/.opencode/agents/demo-agent.md" "export opencode: agent file (no .agent.md suffix)"
  assert_file_exists "$tmp/.opencode/commands/demo-prompt.md" "export opencode: prompt file"
  assert_file_exists "$tmp/.agents/skills/demo-skill/SKILL.md" "export opencode: skill copied to .agents/skills/"
  assert_file_missing "$tmp/.opencode/agents/stale.md" "export opencode: removes stale generated agents"
  assert_file_missing "$tmp/.opencode/agents/manual.md" "export opencode: removes untracked files from managed output"
  assert_file_missing "$tmp/.opencode/commands/manual.md" "export opencode: removes untracked commands"
  assert_file_missing "$tmp/.agents/skills/manual/SKILL.md" "export opencode: reconciles shared skills"
  assert_file_missing "$tmp/.opencode/commands/snippets/branch-name.md" "export opencode: does not copy prompt-dir assets"
}

# ---------------------------------------------------------------------------
# Test: export copilot
# ---------------------------------------------------------------------------
test_export_copilot() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install snippets >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  mkdir -p "$tmp/.github/agents" "$tmp/.github/prompts" "$tmp/.agents/skills/manual"
  : > "$tmp/.github/agents/stale.agent.md"
  : > "$tmp/.github/agents/manual.md"
  : > "$tmp/.github/prompts/manual.prompt.md"
  : > "$tmp/.agents/skills/manual/SKILL.md"
  run_in_project "$tmp" export copilot >/dev/null 2>&1

  assert_file_exists "$tmp/.github/agents/demo-agent.agent.md" "export copilot: agent file (keeps .agent.md suffix)"
  assert_file_exists "$tmp/.github/prompts/demo-prompt.prompt.md" "export copilot: prompt file"
  assert_file_exists "$tmp/.agents/skills/demo-skill/SKILL.md" "export copilot: skill copied to .agents/skills/"
  assert_file_missing "$tmp/.github/agents/stale.agent.md" "export copilot: removes stale generated agents"
  assert_file_missing "$tmp/.github/agents/manual.md" "export copilot: removes untracked files from managed output"
  assert_file_missing "$tmp/.github/prompts/manual.prompt.md" "export copilot: removes untracked prompts"
  assert_file_missing "$tmp/.agents/skills/manual/SKILL.md" "export copilot: reconciles shared skills"
  assert_file_missing "$tmp/.github/prompts/snippets/branch-name.md" "export copilot: does not copy prompt-dir assets"

  # Copilot strips permission block and adds user-invocable: false for subagents
  local content
  content="$(cat "$tmp/.github/agents/demo-agent.agent.md")"
  assert_contains "$content" "user-invocable: false" "export copilot: subagent gets user-invocable: false"
}

# ---------------------------------------------------------------------------
# Test: export pi
# ---------------------------------------------------------------------------
test_export_pi() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"

  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-prompt >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install snippets >/dev/null 2>&1
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-skill >/dev/null 2>&1

  cat > "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md" <<'EOF'
---
description: Pi prompt description
argument-hint: "[focus]"
agent: unsupported-agent
handoffs: unsupported-handoff
---
# Demo Prompt

Use the included context:
#include /.agents/orchestra/prompts/snippets/branch-name.md
EOF

  mkdir -p "$tmp/.pi/prompts" "$tmp/.pi/agents" "$tmp/.agents/skills/manual" "$tmp/.github/agents" "$tmp/.opencode/agents"
  : > "$tmp/.pi/prompts/manual.md"
  : > "$tmp/.pi/prompts/stale.md"
  : > "$tmp/.pi/agents/manual.md"
  : > "$tmp/.agents/skills/manual/SKILL.md"
  : > "$tmp/.github/agents/other-platform.md"
  : > "$tmp/.opencode/agents/other-platform.md"

  run_in_project "$tmp" export pi >/dev/null 2>&1

  local prompt="$tmp/.pi/prompts/demo-prompt.md" content
  assert_file_exists "$prompt" "export pi: emits native prompt template"
  assert_file_missing "$tmp/.pi/prompts/demo-prompt.prompt.md" "export pi: strips source suffix"
  assert_file_missing "$tmp/.pi/prompts/manual.md" "export pi: removes untracked prompt files"
  assert_file_missing "$tmp/.pi/prompts/stale.md" "export pi: removes stale prompt files"
  assert_file_missing "$tmp/.pi/prompts/snippets/branch-name.md" "export pi: does not copy prompt-dir assets"
  assert_file_exists "$tmp/.pi/agents/manual.md" "export pi: leaves non-managed agent files untouched"
  assert_file_exists "$tmp/.agents/skills/demo-skill/SKILL.md" "export pi: uses shared Agent Skills location"
  assert_file_missing "$tmp/.agents/skills/manual/SKILL.md" "export pi: reconciles shared skills"
  assert_file_exists "$tmp/.github/agents/other-platform.md" "export pi: leaves other platform outputs untouched"
  assert_file_exists "$tmp/.opencode/agents/other-platform.md" "export pi: leaves OpenCode outputs untouched"

  content="$(<"$prompt")"
  assert_contains "$content" "description: Pi prompt description" "export pi: preserves prompt description"
  assert_contains "$content" 'argument-hint: "[focus]"' "export pi: preserves Pi argument hint"
  assert_contains "$content" 'Run `git branch --show-current`' "export pi: compiles includes into the prompt body"
  if [[ "$content" == *"unsupported-agent"* || "$content" == *"unsupported-handoff"* ]]; then
    FAIL=$((FAIL + 1))
    FAILURES+=("FAIL: export pi -- unsupported prompt frontmatter was retained")
  else
    PASS=$((PASS + 1))
  fi

  cat > "$tmp/.agents/orchestra/prompts/demo-prompt.prompt.md" <<'EOF'
---
description: Broken prompt
---
#include /.agents/orchestra/prompts/snippets/missing.md
EOF
  local rc=0
  run_in_project "$tmp" export pi >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "1" "export pi: compilation error exits non-zero"
  assert_contains "$(<"$prompt")" "Pi prompt description" "export pi: compile failure leaves previous output intact"

  rm -rf "$tmp/.agents/orchestra/prompts" "$tmp/.agents/orchestra/skills"
  run_in_project "$tmp" export pi >/dev/null 2>&1
  assert_dir_missing "$tmp/.pi/prompts" "export pi: removes empty managed prompt directory"
  assert_dir_missing "$tmp/.agents/skills" "export pi: removes empty shared skill directory"
  assert_dir_exists "$tmp/.pi" "export pi: preserves platform parent directory"
}

# ---------------------------------------------------------------------------
# Test: missing source guard preserves existing outputs
# ---------------------------------------------------------------------------
test_export_missing_source_guard() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  mkdir -p "$tmp/.pi/prompts" "$tmp/.agents/skills/existing"
  : > "$tmp/.pi/prompts/existing.md"
  : > "$tmp/.agents/skills/existing/SKILL.md"

  local rc=0
  run_in_project "$tmp" export pi >/dev/null 2>&1 || rc=$?
  assert_eq "$rc" "1" "export pi: missing source directory is rejected"
  assert_file_exists "$tmp/.pi/prompts/existing.md" "export pi: missing source guard preserves prompts"
  assert_file_exists "$tmp/.agents/skills/existing/SKILL.md" "export pi: missing source guard preserves skills"
}

# ---------------------------------------------------------------------------
# Test: convert copilot -> orchestra
# ---------------------------------------------------------------------------
test_convert_copilot() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  mkdir -p "$tmp/.github/agents"
  cat > "$tmp/.github/agents/imported.agent.md" <<EOF
---
name: imported
description: An imported agent
user-invocable: false
model: gpt-4o
---
# Imported Agent

Do imported things.
EOF

  run_in_project "$tmp" convert copilot imported >/dev/null 2>&1

  assert_file_exists "$tmp/.agents/orchestra/agents/imported.agent.md" "convert writes orchestra definition"

  local content
  content="$(cat "$tmp/.agents/orchestra/agents/imported.agent.md")"
  assert_contains "$content" "mode: subagent" "convert maps user-invocable: false -> mode: subagent"
}

# ---------------------------------------------------------------------------
# Test: install --locked uses locked SHA
# ---------------------------------------------------------------------------
test_install_locked() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  setup_cached_source "$tmp"
  printf 'orchestrator: gpt-4o\nsubagent: claude-sonnet\n' > "$tmp/.orchestra/config.yml"
  local cached_sha="cached111cached111cached111cached111cac"
  echo "$cached_sha" > "$tmp/.orchestra/pkg-cache/core/head.sha"

  # First install at cached SHA
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent >/dev/null 2>&1
  local locked_sha
  locked_sha="$(yq -r '.packages[] | select(.name=="demo-agent") | .sha' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$locked_sha" "$cached_sha" "first install locks cached SHA"

  # Now bump the cached SHA — install --locked should NOT pick it up
  local new_sha="newsha222newsha222newsha222newsha222new"
  echo "$new_sha" > "$tmp/.orchestra/pkg-cache/core/head.sha"

  rm -f "$tmp/.agents/orchestra/agents/demo-agent.agent.md"
  ORCHESTRA_YES=1 run_in_project "$tmp" install demo-agent --locked >/dev/null 2>&1

  local locked_after
  locked_after="$(yq -r '.packages[] | select(.name=="demo-agent") | .sha' "$tmp/.orchestra/pkg.lock.yaml")"
  assert_eq "$locked_after" "$cached_sha" "install --locked keeps original SHA, ignores new cache"
}

# ---------------------------------------------------------------------------
# Test: source add rejects duplicate repo
# ---------------------------------------------------------------------------
test_source_add_duplicate() {
  local tmp
  tmp="$(setup_test)"
  trap "teardown_test_project $tmp" RETURN

  write_test_sources_list "$tmp"

  local out rc
  out="$(run_in_project "$tmp" source add test/source secondary 2>&1)" || rc=$?
  rc="${rc:-0}"
  assert_eq "$rc" "1" "source add duplicate exits non-zero"
  assert_contains "$out" "already configured" "source add duplicate explains conflict"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  echo "Running Orchestra test suite..."
  echo ""

  local tests=(
    test_gitignore_for_project_state
    test_help_version
    test_nested_project_directory
    test_completion_from_nested_directory
    test_source_list_default
    test_generate_manifest
    test_standalone_manifest
    test_standalone_self_update
    test_install_agent_silent_model
    test_install_prompt
    test_install_skill_multifile
    test_install_prompt_dir
    test_install_all
    test_list_installed
    test_search
    test_info_installed
    test_info_available
    test_status_reports_managed_paths
    test_status_reports_missing_and_untracked
    test_status_without_lockfile
    test_remove
    test_remove_missing_file
    test_fork_detaches_packages
    test_push_agent_pull_request
    test_push_skill_pull_request
    test_push_direct_updates_lock
    test_push_requires_source_permission
    test_push_dry_run_does_not_publish
    test_push_rejects_source_conflict
    test_fork_remove_and_source_remove
    test_upgrade_sha_change
    test_upgrade_uptodate
    test_upgrade_preserves_model
    test_upgrade_bulk_overwrites_without_prompt
    test_source_subscribe_future_packages
    test_source_unsubscribe_stops_future_packages
    test_install_injects_model_into_source_without_one
    test_source_remove_refuses
    test_source_remove_succeeds
    test_export_opencode
    test_export_copilot
    test_export_pi
    test_export_missing_source_guard
    test_convert_copilot
    test_install_locked
    test_source_add_duplicate
  )

  for t in "${tests[@]}"; do
    echo -n "  $t ... "
    if "$t" 2>&1; then
      echo "ok"
    else
      echo "FAIL"
      FAIL=$((FAIL + 1))
      FAILURES+=("FAIL: $t exited non-zero")
    fi
  done

  echo ""
  echo "Pass: $PASS"
  echo "Fail: $FAIL"

  if [ "$FAIL" -gt 0 ]; then
    echo ""
    for f in "${FAILURES[@]}"; do
      echo "  $f" >&2
    done
    exit 1
  fi
  exit 0
}

main "$@"
