#!/bin/bash

set -euo pipefail

if [ -n "${1-}" ]; then
  echo "Usage: ./ai/orchestra/copilot.install.sh"
  exit 1
fi

if [ ! -d "ai/orchestra" ]; then
  echo "Please run this script from the project root."
  exit 1
fi

MODULE_NAME="orchestra"
MODULE_DIR="ai/${MODULE_NAME}"

echo "Installing ${MODULE_NAME} for GitHub Copilot..."

mkdir -p .github/agents
rm -f .github/agents/${MODULE_NAME}*

mkdir -p .github/prompts
rm -rf .github/prompts/${MODULE_NAME}*

mkdir -p .agents/skills
rm -rf .agents/skills/${MODULE_NAME}*

mkdir -p .orchestra

if [ -d "$MODULE_DIR/skills" ]; then
  cp -r "$MODULE_DIR/skills/"* .agents/skills/ 2>/dev/null || true
fi

CONFIGURE_SCRIPT="$MODULE_DIR/scripts/configure.sh"
if [ -f "$CONFIGURE_SCRIPT" ]; then
  bash "$CONFIGURE_SCRIPT" "$MODULE_NAME" copilot
fi

echo "Done."
