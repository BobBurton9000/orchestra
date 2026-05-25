#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

usage() {
  echo "Usage: $0 <copilot|opencode> [name]" >&2
  echo "" >&2
  echo "  Converts existing platform agent files into Orchestra definition files" >&2
  echo "  stored at .agents/orchestra/agents/<name>.agent.md" >&2
  echo "" >&2
  echo "  Run without [name] to convert ALL agents from that platform." >&2
  echo "  Run with [name] to convert a single agent." >&2
  echo "" >&2
  echo "  Examples:" >&2
  echo "    $0 copilot              # converts all .github/agents/*.agent.md" >&2
  echo "    $0 copilot architect    # converts .github/agents/architect.agent.md" >&2
  echo "    $0 opencode             # converts all .opencode/agents/*.md" >&2
  echo "    $0 opencode architect   # converts .opencode/agents/architect.md" >&2
  exit 1
}

if [ $# -lt 1 ]; then
  usage
fi

PLATFORM="$1"
AGENT_NAME="${2:-}"

case "$PLATFORM" in
  copilot)   SRC_DIR="$PROJECT_ROOT/.github/agents" ;;
  opencode)  SRC_DIR="$PROJECT_ROOT/.opencode/agents" ;;
  *)
    echo "ERROR: Unsupported platform: $PLATFORM" >&2
    usage
    ;;
esac

if [ ! -d "$SRC_DIR" ]; then
  echo "No agents directory found at $SRC_DIR" >&2
  exit 1
fi

DEST_DIR="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR/agents"
mkdir -p "$DEST_DIR"

ask_overwrite() {
  local label="$1"
  read -rp "$label already exists. Overwrite? [y/N] " answer
  if [ "${answer,,}" != "y" ] && [ "${answer,,}" != "yes" ]; then
    echo "  Skipped."
    return 1
  fi
  return 0
}

infer_mode() {
  local desc="$1"
  local name="$2"

  if [ "$name" = "orchestrator" ]; then
    echo "primary"
    return
  fi

  if [[ "$desc" =~ [Oo]rchestrat ]]; then
    echo "primary"
    return
  fi

  echo "subagent"
}

convert_copilot_agent() {
  local src="$1"
  local dest="$2"

  local name description model user_invocable agents body

  name=$(read_frontmatter_value name "$src")
  description=$(read_frontmatter_value description "$src")
  model=$(read_frontmatter_value model "$src")
  user_invocable=$(read_frontmatter_value user-invocable "$src")
  agents=$(awk '
    /^---[[:space:]]*$/ { m++; next }
    m==1 && /^agents:[[:space:]]/ { print; exit }
  ' "$src" | sed 's/^agents:[[:space:]]*//' | tr -d '\r')

  local mode
  if [ "$user_invocable" = "false" ]; then
    mode="subagent"
  else
    mode="primary"
  fi

  if [ -z "$name" ]; then
    name=$(basename "$src" .agent.md)
    echo "  Warning: no name key, using filename: $name"
  fi

  body=$(write_body_without_frontmatter "$src")

  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$name"
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    printf 'mode: %s\n' "$mode"
    [ -n "$agents" ] && printf 'agents: %s\n' "$agents"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    printf '%s\n\n' '---'
    printf '%s\n' "$body"
  } > "$dest"
}

convert_opencode_agent() {
  local src="$1"
  local dest="$2"

  local description mode model permissions body

  description=$(read_frontmatter_value description "$src")
  mode=$(read_frontmatter_value mode "$src")
  model=$(read_frontmatter_value model "$src")
  permissions=$(read_frontmatter_block permission "$src")

  local name
  if [[ "$src" =~ /([^/]+)\.md$ ]]; then
    name="${BASH_REMATCH[1]}"
  else
    name=$(basename "$src" .md)
  fi

  body=$(write_body_without_frontmatter "$src")

  {
    printf '%s\n' '---'
    printf 'name: %s\n' "$name"
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    [ -n "$mode" ] && printf 'mode: %s\n' "$mode"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    if [ -n "$permissions" ]; then
      printf 'permission:\n'
      printf '%s\n' "$permissions"
    fi
    printf '%s\n\n' '---'
    printf '%s\n' "$body"
  } > "$dest"
}

converted=0

if [ -n "$AGENT_NAME" ]; then
  case "$PLATFORM" in
    copilot)
      src="$SRC_DIR/${AGENT_NAME}.agent.md"
      dest="$DEST_DIR/${AGENT_NAME}.agent.md"
      ;;
    opencode)
      src="$SRC_DIR/${AGENT_NAME}.md"
      dest="$DEST_DIR/${AGENT_NAME}.agent.md"
      ;;
  esac

  if [ ! -f "$src" ]; then
    echo "ERROR: Agent not found: $src" >&2
    exit 1
  fi

  if [ -f "$dest" ]; then
    if ! ask_overwrite "agents/${AGENT_NAME}.agent.md"; then
      exit 0
    fi
  fi

  case "$PLATFORM" in
    copilot)  convert_copilot_agent "$src" "$dest" ;;
    opencode) convert_opencode_agent "$src" "$dest" ;;
  esac

  echo "Converted: $dest"
  converted=1
else
  echo "Converting agents from $PLATFORM..."
  echo ""

  for src in "$SRC_DIR"/*; do
    [ -f "$src" ] || continue

    name=""; dest=""

    case "$PLATFORM" in
      copilot)
        if [[ "$src" != *.agent.md ]]; then
          continue
        fi
        name=$(basename "$src" .agent.md)
        dest="$DEST_DIR/${name}.agent.md"
        ;;
      opencode)
        if [[ "$src" != *.md ]]; then
          continue
        fi
        name=$(basename "$src" .md)
        dest="$DEST_DIR/${name}.agent.md"
        ;;
    esac

    if [ -f "$dest" ]; then
      if ! ask_overwrite "agents/${name}.agent.md"; then
        continue
      fi
    fi

    case "$PLATFORM" in
      copilot)  convert_copilot_agent "$src" "$dest" ;;
      opencode) convert_opencode_agent "$src" "$dest" ;;
    esac

    echo "  + agents/${name}.agent.md"
    converted=$((converted + 1))
  done
fi

echo ""
echo "Converted $converted agent(s) from $PLATFORM to .agents/orchestra/agents/"
[ "$converted" -gt 0 ] && echo "Ready to export: run '.orchestra/export.sh copilot' or '.orchestra/export.sh opencode'"
