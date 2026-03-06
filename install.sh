#!/bin/bash

if [ -n "$1" ]; then
  echo "Usage: ./ai/orchestra/install.sh"
  exit 1
fi

# Ensure we run from the project root
if [ ! -d ".github" ] || [ ! -d "ai/orchestra" ]; then
  echo "Please run this script from the project root."
  exit 1
fi

MODULE_NAME="orchestra"
MODULE_DIR="ai/${MODULE_NAME}"

echo "Installing ${MODULE_NAME}..."

mkdir -p .github/agents
rm -f .github/agents/${MODULE_NAME}*

if [ -d "$MODULE_DIR/agents" ]; then
  cp -r "$MODULE_DIR/agents/"* .github/agents/ 2>/dev/null || true
fi

mkdir -p .github/prompts
rm -f .github/prompts/${MODULE_NAME}*

if [ -d "$MODULE_DIR/prompts" ]; then
  cp "$MODULE_DIR/prompts/${MODULE_NAME}"* .github/prompts/ 2>/dev/null || true
fi

if [ -d ".agents/skills" ]; then
  rm -rf .agents/skills/${MODULE_NAME}*
  rm -rf .agents/skills/zz-${MODULE_NAME}*
fi

CONFIGURE_SCRIPT="$MODULE_DIR/scripts/configure.sh"
if [ -f "$CONFIGURE_SCRIPT" ]; then
  bash "$CONFIGURE_SCRIPT" "$MODULE_NAME"
fi

echo "Done."