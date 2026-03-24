#!/bin/bash

set -euo pipefail

if [ -n "${1-}" ]; then
  echo "Usage: ./ai/orchestra/opencode.uninstall.sh"
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
    agent_name=${agent_name#${MODULE_NAME}.}
    agent_name=${agent_name%.agent.md}
    rm -f ".opencode/agents/${agent_name}.md"
  done
}

echo "Uninstalling ${MODULE_NAME} from OpenCode..."

if [ -d ".opencode/agents" ]; then
  remove_installed_agents
fi

if [ -d ".opencode/commands" ]; then
  rm -rf .opencode/commands/${MODULE_NAME}*
fi

if [ -d ".agents/skills" ]; then
  rm -rf .agents/skills/${MODULE_NAME}*
  rm -rf .agents/skills/zz-${MODULE_NAME}*
fi

if [ -d ".agents/orchestra" ]; then
  rm -rf .agents/orchestra
fi

echo "Done."