#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

ORCHESTRA_TEMP="$PROJECT_ROOT/$ORCHESTRA_DIR/.temp"
COMPILE_SCRIPT="$SCRIPT_DIR/scripts/compile.sh"

usage() {
  echo "Usage: $0 <copilot|opencode>" >&2
  echo "" >&2
  echo "  Compiles all agent, prompt, and skill definitions from" >&2
  echo "  .agents/orchestra/ and exports them for the target platform." >&2
  exit 1
}

cleanup() {
  rm -rf "$ORCHESTRA_TEMP"
}

trap cleanup EXIT

if [ $# -lt 1 ]; then
  usage
fi

PLATFORM="$1"

case "$PLATFORM" in
  copilot)
    AGENTS_OUT=".github/agents"
    PROMPTS_OUT=".github/prompts"
    ;;
  opencode)
    AGENTS_OUT=".opencode/agents"
    PROMPTS_OUT=".opencode/commands"
    ;;
  *)
    echo "ERROR: Unsupported platform: $PLATFORM" >&2
    usage
    ;;
esac

DEFS_DIR="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR"

if [ ! -d "$DEFS_DIR" ]; then
  echo "No definitions found at $AGENTS_ORCHESTRA_DIR" >&2
  echo "Run '.orchestra/import.sh <name>' or '.orchestra/import-defaults.sh' first." >&2
  exit 1
fi

rm -rf "$ORCHESTRA_TEMP"
mkdir -p "$ORCHESTRA_TEMP/agents" "$ORCHESTRA_TEMP/prompts" "$ORCHESTRA_TEMP/skills"

EXPORT_COUNT=0
MANIFEST=""

record_output() {
  MANIFEST="$MANIFEST$1"$'\n'
}

compile_single() {
  local src="$1"
  local dst="$2"

  bash "$COMPILE_SCRIPT" "$PROJECT_ROOT" "$src" "$dst"
}

prepare_copilot_agent() {
  local compiled="$1"
  local final="$2"

  local name description model mode
  name=$(read_frontmatter_value name "$compiled")
  description=$(read_frontmatter_value description "$compiled")
  model=$(read_frontmatter_value model "$compiled")
  mode=$(read_frontmatter_value mode "$compiled")

  local agents
  agents=$(awk '
    /^---[[:space:]]*$/ { m++; next }
    m==1 && /^agents:[[:space:]]/ { print; exit }
  ' "$compiled" | sed 's/^agents:[[:space:]]*//' | tr -d '\r')

  local body
  body=$(write_body_without_frontmatter "$compiled")

  {
    printf '%s\n' '---'
    [ -n "$name" ] && printf 'name: %s\n' "$name"
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    if [ "$mode" = "subagent" ]; then
      printf 'user-invocable: false\n'
    fi
    [ -n "$agents" ] && printf 'agents: %s\n' "$agents"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    printf '%s\n\n' '---'
    printf '%s\n' "$body"
  } > "$final"
}

prepare_opencode_agent() {
  local compiled="$1"
  local final="$2"

  local description mode model permissions
  description=$(read_frontmatter_value description "$compiled")
  mode=$(read_frontmatter_value mode "$compiled")
  model=$(read_frontmatter_value model "$compiled")
  permissions=$(read_frontmatter_block permission "$compiled")

  local body
  body=$(write_body_without_frontmatter "$compiled")

  {
    printf '%s\n' '---'
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    [ -n "$mode" ] && printf 'mode: %s\n' "$mode"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    if [ -n "$permissions" ]; then
      printf 'permission:\n'
      printf '%s\n' "$permissions"
    fi
    printf '%s\n\n' '---'
    printf '%s\n' "$body"
  } > "$final"
}

prepare_copilot_prompt() {
  local compiled="$1"
  local final="$2"
  cp "$compiled" "$final"
}

prepare_opencode_prompt() {
  local compiled="$1"
  local final="$2"

  local description agent
  description=$(read_frontmatter_value description "$compiled")
  agent=$(read_frontmatter_value agent "$compiled")

  local body
  body=$(write_body_without_frontmatter "$compiled")

  {
    printf '%s\n' '---'
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    if [ -n "$agent" ] && [ "$agent" != "agent" ]; then
      printf 'agent: %s\n' "$agent"
    fi
    printf '%s\n\n' '---'
    printf '%s\n' "$body"
  } > "$final"
}

process_agents() {
  local src_dir="$DEFS_DIR/agents"
  [ -d "$src_dir" ] || return 0

  for src_file in "$src_dir/"*.agent.md; do
    [ -f "$src_file" ] || continue

    local name
    name=$(basename "$src_file" .agent.md)
    local compiled="$ORCHESTRA_TEMP/agents/${name}.agent.md"

    compile_single "$src_file" "$compiled"
    EXPORT_COUNT=$((EXPORT_COUNT + 1))

    case "$PLATFORM" in
      copilot)
        local copilot_out="$PROJECT_ROOT/$AGENTS_OUT/${name}.agent.md"
        mkdir -p "$(dirname "$copilot_out")"
        prepare_copilot_agent "$compiled" "$copilot_out"
        record_output "$AGENTS_OUT/${name}.agent.md"
        ;;
      opencode)
        local opencode_out="$PROJECT_ROOT/$AGENTS_OUT/${name}.md"
        mkdir -p "$(dirname "$opencode_out")"
        prepare_opencode_agent "$compiled" "$opencode_out"
        record_output "$AGENTS_OUT/${name}.md"
        ;;
    esac
  done
}

process_prompts() {
  local src_dir="$DEFS_DIR/prompts"
  [ -d "$src_dir" ] || return 0

  for src_file in "$src_dir/"*.prompt.md; do
    [ -f "$src_file" ] || continue

    local name
    name=$(basename "$src_file" .prompt.md)
    local compiled="$ORCHESTRA_TEMP/prompts/${name}.prompt.md"

    compile_single "$src_file" "$compiled"
    EXPORT_COUNT=$((EXPORT_COUNT + 1))

    case "$PLATFORM" in
      copilot)
        local copilot_out="$PROJECT_ROOT/$PROMPTS_OUT/${name}.prompt.md"
        mkdir -p "$(dirname "$copilot_out")"
        prepare_copilot_prompt "$compiled" "$copilot_out"
        record_output "$PROMPTS_OUT/${name}.prompt.md"
        ;;
      opencode)
        local opencode_out="$PROJECT_ROOT/$PROMPTS_OUT/${name}.md"
        mkdir -p "$(dirname "$opencode_out")"
        prepare_opencode_prompt "$compiled" "$opencode_out"
        record_output "$PROMPTS_OUT/${name}.md"
        ;;
    esac
  done

  local subdir
  for subdir in snippets templates config; do
    local src_sub="$src_dir/$subdir"
    if [ -d "$src_sub" ]; then
      case "$PLATFORM" in
        copilot)
          local dst_sub="$PROJECT_ROOT/$PROMPTS_OUT/$subdir"
          mkdir -p "$dst_sub"
          for item in "$src_sub/"*; do
            [ -e "$item" ] || continue
            local item_name
            item_name=$(basename "$item")
            local compiled="$ORCHESTRA_TEMP/prompts/${subdir}_${item_name}"
            compile_single "$item" "$compiled"
            cp "$compiled" "$dst_sub/$item_name"
            record_output "$PROMPTS_OUT/$subdir/$item_name"
            EXPORT_COUNT=$((EXPORT_COUNT + 1))
          done
          ;;
        opencode)
          local dst_sub="$PROJECT_ROOT/$PROMPTS_OUT/$subdir"
          mkdir -p "$dst_sub"
          for item in "$src_sub/"*; do
            [ -e "$item" ] || continue
            local item_name
            item_name=$(basename "$item")
            local compiled="$ORCHESTRA_TEMP/prompts/${subdir}_${item_name}"
            compile_single "$item" "$compiled"
            cp "$compiled" "$dst_sub/$item_name"
            record_output "$PROMPTS_OUT/$subdir/$item_name"
            EXPORT_COUNT=$((EXPORT_COUNT + 1))
          done
          ;;
      esac
    fi
  done
}

process_skills() {
  local src_dir="$DEFS_DIR/skills"
  [ -d "$src_dir" ] || return 0

  local skills_out="$PROJECT_ROOT/.agents/skills"
  mkdir -p "$skills_out"

  for skill_dir in "$src_dir/"*/; do
    [ -d "$skill_dir" ] || continue

    local skill_name
    skill_name=$(basename "$skill_dir")
    local skill_src="$skill_dir/SKILL.md"
    [ -f "$skill_src" ] || continue

    local compiled="$ORCHESTRA_TEMP/skills/${skill_name}.md"

    compile_single "$skill_src" "$compiled"

    local dst="$skills_out/$skill_name"
    mkdir -p "$dst"
    cp "$compiled" "$dst/SKILL.md"
    record_output ".agents/skills/$skill_name/SKILL.md"
    EXPORT_COUNT=$((EXPORT_COUNT + 1))
  done
}

echo "Exporting for $PLATFORM..."

process_agents
process_prompts
process_skills

MANIFEST_FILE="$PROJECT_ROOT/$ORCHESTRA_DIR/.manifest"
printf '%s\n' "$MANIFEST" > "$MANIFEST_FILE"

echo ""
echo "Export complete."
echo "  Platform: $PLATFORM"
echo "  Compiled: $EXPORT_COUNT files"
echo "  Manifest: $ORCHESTRA_DIR/.manifest"
