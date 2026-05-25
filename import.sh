#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

ORCHESTRA_TEMPLATES="$SCRIPT_DIR/templates"

usage() {
  echo "Usage: $0 <name>" >&2
  echo "" >&2
  echo "  Imports an agent, prompt, or skill from the Orchestra templates" >&2
  echo "" >&2
  echo "  Examples:" >&2
  echo "    $0 orchestrator                 # imports agents/orchestrator.agent.md" >&2
  echo "    $0 agents/architect             # imports agents/architect.agent.md" >&2
  echo "    $0 prompts/create-playbook      # imports prompts/create-playbook.prompt.md" >&2
  echo "    $0 skills/writing-gherkin       # imports skills/writing-gherkin/SKILL.md" >&2
  exit 1
}

guess_namespace() {
  local name="$1"

  if [[ "$name" == agents/* ]] || [[ "$name" == prompts/* ]] || [[ "$name" == skills/* ]]; then
    echo "$name"
    return
  fi

  for ns in agents prompts skills; do
    local candidate=""
    case "$ns" in
      agents)  candidate="$ORCHESTRA_TEMPLATES/$ns/${name}.agent.md" ;;
      prompts) candidate="$ORCHESTRA_TEMPLATES/$ns/${name}.prompt.md" ;;
      skills)  candidate="$ORCHESTRA_TEMPLATES/$ns/${name}/SKILL.md" ;;
    esac
    if [ -f "$candidate" ]; then
      echo "$ns/$name"
      return
    fi
  done

  echo "ERROR: No template found for '$name'. Tried agents/, prompts/, skills/." >&2
  echo "Try one of:" >&2
  ls "$ORCHESTRA_TEMPLATES/agents/" | sed 's/\.agent\.md$//' | head -5 >&2
  echo "  ... (run with no args to see usage)" >&2
  exit 1
}

import_agent() {
  local template_path="$1"
  local target_path="$2"

  if [ -f "$target_path" ]; then
    read -rp "Agent '$(basename "$target_path" .agent.md)' already exists. Overwrite? [y/N] " answer
    if [ "${answer,,}" != "y" ] && [ "${answer,,}" != "yes" ]; then
      echo "Skipped."
      return 0
    fi
  fi

  mkdir -p "$(dirname "$target_path")"

  local config_file="$PROJECT_ROOT/$ORCHESTRA_DIR/config.yml"
  local default_model=""
  local model_prompt_text=""

  if [ -f "$config_file" ]; then
    local agent_name
    agent_name=$(read_frontmatter_value name "$template_path")
    if [ "$agent_name" = "orchestrator" ]; then
      default_model=$(awk '/^orchestrator:/{print $2}' "$config_file" 2>/dev/null || echo "")
      model_prompt_text=" [orchestrator default: $default_model]"
    else
      default_model=$(awk '/^subagent:/{print $2}' "$config_file" 2>/dev/null || echo "")
      model_prompt_text=" [subagent default: $default_model]"
    fi
  fi

  read -rp "Model for this agent${model_prompt_text}: " model_input

  if [ -z "$model_input" ] && [ -n "$default_model" ]; then
    model_input="$default_model"
    echo "Using default: $model_input"
  fi

  if [ -z "$model_input" ]; then
    echo "ERROR: No model specified." >&2
    exit 1
  fi

  local temp_fm
  temp_fm=$(mktemp)
  local current_model
  current_model=$(read_frontmatter_value model "$template_path" 2>/dev/null || echo "")

  awk -v model="$model_input" '
    /^model:[[:space:]]/ { print "model: " model; next }
    { print }
  ' "$template_path" > "$temp_fm"

  mv "$temp_fm" "$target_path"
  echo "Imported: $target_path"
}

import_prompt() {
  local template_path="$1"
  local target_path="$2"

  local target_name
  target_name=$(basename "$target_path" .prompt.md)

  if [ -f "$target_path" ]; then
    read -rp "Prompt '$target_name' already exists. Overwrite? [y/N] " answer
    if [ "${answer,,}" != "y" ] && [ "${answer,,}" != "yes" ]; then
      echo "Skipped."
      return 0
    fi
  fi

  mkdir -p "$(dirname "$target_path")"
  cp "$template_path" "$target_path"
  echo "Imported: $target_path"
}

import_skill() {
  local template_dir="$1"
  local target_dir="$2"

  local skill_name
  skill_name=$(basename "$target_dir")

  if [ -d "$target_dir" ]; then
    read -rp "Skill '$skill_name' already exists. Overwrite? [y/N] " answer
    if [ "${answer,,}" != "y" ] && [ "${answer,,}" != "yes" ]; then
      echo "Skipped."
      return 0
    fi
  fi

  mkdir -p "$target_dir"
  cp "$template_dir/SKILL.md" "$target_dir/SKILL.md"
  echo "Imported: $target_dir/SKILL.md"
}

if [ $# -lt 1 ]; then
  usage
fi

IMPORT_NAME="$1"
RESOLVED=$(guess_namespace "$IMPORT_NAME")
NS_PATH="${RESOLVED#*/}"
NAMESPACE="${RESOLVED%%/*}"

TARGET_BASE="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR/$NAMESPACE"

case "$NAMESPACE" in
  agents)
    TEMPLATE_SRC="$ORCHESTRA_TEMPLATES/agents/${NS_PATH}.agent.md"
    TARGET_DST="$TARGET_BASE/${NS_PATH}.agent.md"
    [ -f "$TEMPLATE_SRC" ] || { echo "ERROR: Template not found: $TEMPLATE_SRC" >&2; exit 1; }
    import_agent "$TEMPLATE_SRC" "$TARGET_DST"
    ;;
  prompts)
    TEMPLATE_SRC="$ORCHESTRA_TEMPLATES/prompts/${NS_PATH}.prompt.md"
    TARGET_DST="$TARGET_BASE/${NS_PATH}.prompt.md"
    [ -f "$TEMPLATE_SRC" ] || { echo "ERROR: Template not found: $TEMPLATE_SRC" >&2; exit 1; }
    import_prompt "$TEMPLATE_SRC" "$TARGET_DST"
    ;;
  skills)
    TEMPLATE_SRC="$ORCHESTRA_TEMPLATES/skills/${NS_PATH}"
    TARGET_DST="$TARGET_BASE/${NS_PATH}"
    [ -d "$TEMPLATE_SRC" ] || { echo "ERROR: Template not found: $TEMPLATE_SRC" >&2; exit 1; }
    import_skill "$TEMPLATE_SRC" "$TARGET_DST"
    ;;
  *)
    echo "ERROR: Unknown namespace: $NAMESPACE" >&2
    exit 1
    ;;
esac
