#!/bin/bash

MODULE_NAME=$1
AGENTS_DIR=".github/agents"
MODULE_DIR="ai/${MODULE_NAME}"
SUBAGENT_MODELS_FILE="${MODULE_DIR}/subagent-models.txt"
ORCHESTRATOR_MODELS_FILE="${MODULE_DIR}/orchestrator-models.txt"

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

SUBAGENT_MODEL=$(select_model "Select a model for subagents (programmers, reviewers, testers, product-manager, UX, etc.):" "$SUBAGENT_MODELS_FILE")
ORCHESTRATOR_MODEL=$(select_model "Select a model for the orchestrator agent:" "$ORCHESTRATOR_MODELS_FILE")

echo ""

# Substitute placeholders in all copied agent files for this module
for file in "$AGENTS_DIR/${MODULE_NAME}"*.md; do
  [ -f "$file" ] || continue
  [ -n "$SUBAGENT_MODEL" ]     && sed -i "s/\${SUBAGENT_MODEL}/${SUBAGENT_MODEL}/g" "$file"
  [ -n "$ORCHESTRATOR_MODEL" ] && sed -i "s/\${ORCHESTRATOR_MODEL}/${ORCHESTRATOR_MODEL}/g" "$file"
done

echo "Models applied to all ${MODULE_NAME} agents."
