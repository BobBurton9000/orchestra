#!/bin/bash

if [ -n "$1" ]; then
  echo "Usage: ./ai/orchestra/uninstall.sh"
  exit 1
fi

# Ensure we run from the project root
if [ ! -d ".github" ] || [ ! -d "ai/orchestra" ]; then
  echo "Please run this script from the project root."
  exit 1
fi

MODULE_NAME="orchestra"

echo "Uninstalling ${MODULE_NAME}..."

if [ -d ".github/agents" ]; then
  rm -f .github/agents/${MODULE_NAME}*
fi

if [ -d ".github/prompts" ]; then
  rm -rf .github/prompts/${MODULE_NAME}*
fi

if [ -d "ai/${MODULE_NAME}/config" ] && [ -d ".github/config" ]; then
  for config_file in "ai/${MODULE_NAME}/config/"*; do
    if [ -f "$config_file" ]; then
      rm -f ".github/config/$(basename "$config_file")"
    fi
  done

  rmdir --ignore-fail-on-non-empty .github/config 2>/dev/null || true
fi

if [ -d ".agents/skills" ]; then
  rm -rf .agents/skills/${MODULE_NAME}*
  rm -rf .agents/skills/zz-${MODULE_NAME}*
fi

echo "Done."