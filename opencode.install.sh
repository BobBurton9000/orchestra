#!/bin/bash

set -euo pipefail

if [ -n "${1-}" ]; then
  echo "Usage: ./ai/orchestra/opencode.install.sh"
  exit 1
fi

if [ ! -d "ai/orchestra" ]; then
  echo "Please run this script from the project root."
  exit 1
fi

MODULE_NAME="orchestra"
MODULE_DIR="ai/${MODULE_NAME}"

remove_installed_agents() {
  local source_file agent_name

  [ -d ".opencode/agents" ] || return 0

  for source_file in "$MODULE_DIR"/agents/"${MODULE_NAME}"*.agent.md; do
    [ -f "$source_file" ] || continue
    agent_name=$(basename "$source_file")
    rm -f ".opencode/agents/${agent_name%.agent.md}.md"
    agent_name=${agent_name#${MODULE_NAME}.}
    agent_name=${agent_name%.agent.md}
    rm -f ".opencode/agents/${agent_name}.md"
  done
}

echo "Installing ${MODULE_NAME} for OpenCode..."

mkdir -p .opencode/agents
remove_installed_agents

mkdir -p .opencode/commands
rm -rf .opencode/commands/${MODULE_NAME}*

mkdir -p .agents/skills
rm -rf .agents/skills/${MODULE_NAME}*

mkdir -p .agents/orchestra

if [ -d "$MODULE_DIR/skills" ]; then
  cp -r "$MODULE_DIR/skills/"* .agents/skills/ 2>/dev/null || true
fi

CONFIGURE_SCRIPT="$MODULE_DIR/scripts/configure.sh"
if [ -f "$CONFIGURE_SCRIPT" ]; then
  bash "$CONFIGURE_SCRIPT" "$MODULE_NAME" opencode
fi

echo "Done."
