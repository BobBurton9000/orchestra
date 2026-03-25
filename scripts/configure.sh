#!/bin/bash

set -euo pipefail

MODULE_NAME=$1
PLATFORM=$2
MODULE_DIR="ai/${MODULE_NAME}"

case "$PLATFORM" in
  copilot)
    AGENTS_DIR=".github/agents"
    PROMPTS_DIR=".github/prompts"
    SUBAGENT_MODELS_FILE="${MODULE_DIR}/copilot.subagent-models.txt"
    ORCHESTRATOR_MODELS_FILE="${MODULE_DIR}/copilot.orchestrator-models.txt"
    ;;
  opencode)
    AGENTS_DIR=".opencode/agents"
    PROMPTS_DIR=".opencode/commands"
    SUBAGENT_MODELS_FILE="${MODULE_DIR}/opencode.subagent-models.txt"
    ORCHESTRATOR_MODELS_FILE="${MODULE_DIR}/opencode.orchestrator-models.txt"
    ;;
  *)
    echo "Unsupported platform: ${PLATFORM}" >&2
    exit 1
    ;;
esac

select_model() {
  local PROMPT_LABEL=$1
  local CONFIG_FILE=$2

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "No models config found at $CONFIG_FILE, skipping."
    return 1
  fi

  mapfile -t MODELS < "$CONFIG_FILE"

  if [ "${#MODELS[@]}" -eq 0 ]; then
    echo "No models defined in $CONFIG_FILE, skipping."
    return 1
  fi

  echo "" >&2
  echo "$PROMPT_LABEL" >&2
  echo "" >&2

  for i in "${!MODELS[@]}"; do
    echo "  $((i+1))) ${MODELS[$i]}" >&2
  done

  echo "" >&2

  while true; do
    read -rp "Enter number (1-${#MODELS[@]}): " CHOICE
    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#MODELS[@]}" ]; then
      break
    fi
    echo "Invalid selection, please try again." >&2
  done

  echo "${MODELS[$((CHOICE-1))]}"
}

read_frontmatter_value() {
  local KEY=$1
  local FILE_PATH=$2

  awk -v key="$KEY" '
    BEGIN { in_frontmatter = 0 }

    /^---[[:space:]]*$/ {
      if (in_frontmatter == 0) {
        in_frontmatter = 1
        next
      }
      exit
    }

    in_frontmatter == 1 {
      pattern = "^" key ":[[:space:]]*"
      if ($0 ~ pattern) {
        sub(pattern, "", $0)
        print
        exit
      }
    }
  ' "$FILE_PATH" | tr -d '\r'
}

write_body_without_frontmatter() {
  local FILE_PATH=$1

  awk '
    /^---[[:space:]]*$/ {
      marker_count += 1
      next
    }

    marker_count >= 2 {
      print
    }
  ' "$FILE_PATH"
}

resolve_model_value() {
  local VALUE=$1

  case "$VALUE" in
    '${ORCHESTRATOR_MODEL}')
      printf '%s\n' "$ORCHESTRATOR_MODEL"
      ;;
    '${SUBAGENT_MODEL}')
      printf '%s\n' "$SUBAGENT_MODEL"
      ;;
    *)
      printf '%s\n' "$VALUE"
      ;;
  esac
}

install_copilot_agents() {
  mkdir -p "$AGENTS_DIR"

  if [ -d "$MODULE_DIR/agents" ]; then
    cp -r "$MODULE_DIR/agents/"* "$AGENTS_DIR/" 2>/dev/null || true
  fi

  for file in "$AGENTS_DIR/${MODULE_NAME}"*.md; do
    [ -f "$file" ] || continue
    [ -n "$SUBAGENT_MODEL" ] && sed -i "s/\${SUBAGENT_MODEL}/${SUBAGENT_MODEL}/g" "$file"
    [ -n "$ORCHESTRATOR_MODEL" ] && sed -i "s/\${ORCHESTRATOR_MODEL}/${ORCHESTRATOR_MODEL}/g" "$file"
  done
}

install_copilot_prompts() {
  mkdir -p "$PROMPTS_DIR"

  if [ -d "$MODULE_DIR/prompts" ]; then
    cp "$MODULE_DIR/prompts/${MODULE_NAME}"* "$PROMPTS_DIR/" 2>/dev/null || true
  fi

  for prompt_dir in "$MODULE_DIR"/prompts/"${MODULE_NAME}".*; do
    if [ -d "$prompt_dir" ]; then
      target_dir="$PROMPTS_DIR/$(basename "$prompt_dir")"
      mkdir -p "$target_dir"
      cp -r "$prompt_dir"/. "$target_dir"/ 2>/dev/null || true
    fi
  done
}

install_opencode_agents() {
  local source_file target_file source_basename agent_name description model mode

  mkdir -p "$AGENTS_DIR"

  for source_file in "$MODULE_DIR"/agents/"${MODULE_NAME}"*.agent.md; do
    [ -f "$source_file" ] || continue

    source_basename=$(basename "$source_file")
    agent_name=$source_basename
    agent_name=${agent_name#${MODULE_NAME}.}
    agent_name=${agent_name%.agent.md}
    target_file="$AGENTS_DIR/${source_basename%.agent.md}.md"
    description=$(read_frontmatter_value description "$source_file")
    model=$(resolve_model_value "$(read_frontmatter_value model "$source_file")")

    if [ "$agent_name" = "orchestrator" ]; then
      mode="primary"
    else
      mode="subagent"
    fi

    {
      printf '%s\n' '---'
      printf 'description: %s\n' "$description"
      printf 'mode: %s\n' "$mode"
      printf 'model: %s\n' "$model"
      printf '%s\n\n' '---'
      write_body_without_frontmatter "$source_file"
    } > "$target_file"
  done
}

install_opencode_commands() {
  local source_file target_file command_name description agent

  mkdir -p "$PROMPTS_DIR"

  for source_file in "$MODULE_DIR"/prompts/"${MODULE_NAME}"*.prompt.md; do
    [ -f "$source_file" ] || continue

    command_name=$(basename "$source_file")
    command_name=${command_name%.prompt.md}
    target_file="$PROMPTS_DIR/${command_name}.md"
    description=$(read_frontmatter_value description "$source_file")
    agent=$(read_frontmatter_value agent "$source_file")
    if [ -n "$agent" ] && [ "$agent" != "agent" ] && [[ "$agent" != ${MODULE_NAME}.* ]]; then
      agent="${MODULE_NAME}.${agent}"
    fi

    {
      printf '%s\n' '---'
      printf 'description: %s\n' "$description"
      if [ -n "$agent" ] && [ "$agent" != "agent" ]; then
        printf 'agent: %s\n' "$agent"
      fi
      printf '%s\n\n' '---'
      write_body_without_frontmatter "$source_file"
    } > "$target_file"
  done

  for prompt_dir in "$MODULE_DIR"/prompts/"${MODULE_NAME}".*; do
    if [ -d "$prompt_dir" ]; then
      target_dir="$PROMPTS_DIR/$(basename "$prompt_dir")"
      mkdir -p "$target_dir"
      cp -r "$prompt_dir"/. "$target_dir"/ 2>/dev/null || true
    fi
  done
}

SUBAGENT_MODEL=$(select_model "Select a model for subagents (programmers, reviewers, testers, product-manager, UX, etc.):" "$SUBAGENT_MODELS_FILE")
ORCHESTRATOR_MODEL=$(select_model "Select a model for the orchestrator agent:" "$ORCHESTRATOR_MODELS_FILE")

echo ""

case "$PLATFORM" in
  copilot)
    install_copilot_agents
    install_copilot_prompts
    echo "Models applied to all ${MODULE_NAME} GitHub Copilot agents."
    ;;
  opencode)
    install_opencode_agents
    install_opencode_commands
    echo "Models applied to all ${MODULE_NAME} OpenCode agents."
    ;;
esac
