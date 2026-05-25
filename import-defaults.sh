#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/scripts/common.sh"

ORCHESTRA_TEMPLATES="$SCRIPT_DIR/templates"

echo "========================================"
echo "  Orchestra Default Import"
echo "========================================"
echo ""
echo "This will import all prepackaged Orchestra templates"
echo "into .agents/orchestra/ for customisation."
echo ""

read -rp "Default model for the orchestrator agent: " ORCH_MODEL
if [ -z "$ORCH_MODEL" ]; then
  echo "ERROR: No orchestrator model specified." >&2
  exit 1
fi

read -rp "Default model for all subagents: " SUB_MODEL
if [ -z "$SUB_MODEL" ]; then
  echo "ERROR: No subagent model specified." >&2
  exit 1
fi

mkdir -p "$PROJECT_ROOT/$ORCHESTRA_DIR"
cat > "$PROJECT_ROOT/$ORCHESTRA_DIR/config.yml" <<EOF
orchestrator: $ORCH_MODEL
subagent: $SUB_MODEL
EOF

echo ""
echo "Model configuration saved to $ORCHESTRA_DIR/config.yml"
echo ""

imported_agents=0
imported_prompts=0
imported_skills=0

ask_overwrite() {
  local label="$1"
  read -rp "$label already exists. Overwrite? [y/N] " answer
  if [ "${answer,,}" != "y" ] && [ "${answer,,}" != "yes" ]; then
    echo "  Skipped."
    return 1
  fi
  return 0
}

import_agents() {
  local template_src target_dst name model

  for template_src in "$ORCHESTRA_TEMPLATES/agents/"*.agent.md; do
    [ -f "$template_src" ] || continue
    name=$(basename "$template_src")
    target_dst="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR/agents/$name"

    if [ -f "$target_dst" ]; then
      if ! ask_overwrite "  agents/$name"; then
        continue
      fi
    fi

    local agent_name
    agent_name=$(read_frontmatter_value name "$template_src")

    if [ "$agent_name" = "orchestrator" ]; then
      model="$ORCH_MODEL"
    else
      model="$SUB_MODEL"
    fi

    mkdir -p "$(dirname "$target_dst")"

    awk -v model="$model" '
      /^model:[[:space:]]/ { print "model: " model; next }
      { print }
    ' "$template_src" > "$target_dst"

    echo "  + agents/$name"
    imported_agents=$((imported_agents + 1))
  done
}

import_prompts() {
  local template_src target_dst name

  for template_src in "$ORCHESTRA_TEMPLATES/prompts/"*.prompt.md; do
    [ -f "$template_src" ] || continue
    name=$(basename "$template_src")
    target_dst="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR/prompts/$name"

    if [ -f "$target_dst" ]; then
      if ! ask_overwrite "  prompts/$name"; then
        continue
      fi
    fi

    mkdir -p "$(dirname "$target_dst")"
    cp "$template_src" "$target_dst"
    echo "  + prompts/$name"
    imported_prompts=$((imported_prompts + 1))
  done

  local subdir
  for subdir in snippets templates config; do
    if [ -d "$ORCHESTRA_TEMPLATES/prompts/$subdir" ]; then
      local sub_target="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR/prompts/$subdir"
      mkdir -p "$sub_target"
      for item in "$ORCHESTRA_TEMPLATES/prompts/$subdir/"*; do
        [ -e "$item" ] || continue
        local item_name
        item_name=$(basename "$item")
        local item_target="$sub_target/$item_name"
        if [ -f "$item_target" ]; then
          if ! ask_overwrite "  prompts/$subdir/$item_name"; then
            continue
          fi
        fi
        cp "$item" "$item_target"
        echo "  + prompts/$subdir/$item_name"
        imported_prompts=$((imported_prompts + 1))
      done
    fi
  done
}

import_skills() {
  local template_dir target_dir skill_name

  for template_dir in "$ORCHESTRA_TEMPLATES/skills/"*/; do
    [ -d "$template_dir" ] || continue
    skill_name=$(basename "$template_dir")
    target_dir="$PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR/skills/$skill_name"

    if [ -d "$target_dir" ]; then
      if ! ask_overwrite "  skills/$skill_name/SKILL.md"; then
        continue
      fi
    fi

    mkdir -p "$target_dir"
    cp "$template_dir/SKILL.md" "$target_dir/SKILL.md"
    echo "  + skills/$skill_name/SKILL.md"
    imported_skills=$((imported_skills + 1))
  done
}

echo "Importing agents..."
import_agents
echo ""
echo "Importing prompts..."
import_prompts
echo ""
echo "Importing skills..."
import_skills

echo ""
echo "========================================"
echo "  Import Complete"
echo "========================================"
echo ""
echo "  Agents:  $imported_agents"
echo "  Prompts: $imported_prompts"
echo "  Skills:  $imported_skills"
echo ""
echo "  Orchestrator model: $ORCH_MODEL"
echo "  Subagent model:     $SUB_MODEL"
echo ""
echo "All templates imported to .agents/orchestra/"
echo "You can edit them directly to customise behaviour."
echo "Run '.orchestra/export.sh opencode' or '.orchestra/export.sh copilot' to deploy."
