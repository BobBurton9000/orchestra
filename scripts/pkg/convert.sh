#!/bin/bash

set -euo pipefail

_convert_skip_on_decline() {
  if ! ask_overwrite "$1"; then
    echo "  Skipped."
    return 1
  fi
  return 0
}

convert_copilot_agent() {
  local src="$1"
  local dest="$2"

  local name description model user_invocable agents body

  name=$(read_frontmatter_value name "$src")
  description=$(read_frontmatter_value description "$src")
  model=$(read_frontmatter_value model "$src")
  user_invocable=$(read_frontmatter_value user-invocable "$src")
  agents=$(read_agents_field "$src")

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

  local description mode model variant permissions body

  description=$(read_frontmatter_value description "$src")
  mode=$(read_frontmatter_value mode "$src")
  model=$(read_frontmatter_value model "$src")
  variant=$(read_frontmatter_value variant "$src")
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
    [ -n "$variant" ] && printf 'variant: %s\n' "$variant"
    if [ -n "$permissions" ]; then
      printf 'permission:\n'
      printf '%s\n' "$permissions"
    fi
    printf '%s\n\n' '---'
    printf '%s\n' "$body"
  } > "$dest"
}

_convert_one_agent() {
  local platform="$1"
  local src="$2"
  local dest="$3"
  case "$platform" in
    copilot)  convert_copilot_agent "$src" "$dest" ;;
    opencode) convert_opencode_agent "$src" "$dest" ;;
  esac
}

_convert_resolve_single() {
  local platform="$1"
  local src_dir="$2"
  local agent_name="$3"
  case "$platform" in
    copilot)
      _convert_src="$src_dir/${agent_name}.agent.md"
      _convert_dest="${_convert_dest_dir}/${agent_name}.agent.md"
      ;;
    opencode)
      _convert_src="$src_dir/${agent_name}.md"
      _convert_dest="${_convert_dest_dir}/${agent_name}.agent.md"
      ;;
  esac
}

convert_cmd() {
  local platform="${1:-}"
  local agent_name="${2:-}"

  [ -n "$platform" ] || die "Usage: orchestra convert copilot|opencode [name]"

  local project_root="$ORCHESTRA_PROJECT_ROOT"

  local src_dir
  case "$platform" in
    copilot)   src_dir="$project_root/.github/agents" ;;
    opencode)  src_dir="$project_root/.opencode/agents" ;;
    *)
      die "Unsupported platform: $platform (use copilot or opencode)"
      ;;
  esac

  if [ ! -d "$src_dir" ]; then
    die "No agents directory found at ${src_dir#$project_root/}"
  fi

  local _convert_dest_dir="$AGENTS_ORCHESTRA_DIR_ABS/agents"
  mkdir -p "$_convert_dest_dir"

  local converted=0

  if [ -n "$agent_name" ]; then
    local _convert_src="" _convert_dest=""
    _convert_resolve_single "$platform" "$src_dir" "$agent_name"

    if [ ! -f "$_convert_src" ]; then
      die "Agent not found: ${_convert_src#$project_root/}"
    fi

    if [ -f "$_convert_dest" ]; then
      if ! _convert_skip_on_decline "agents/${agent_name}.agent.md"; then
        return 0
      fi
    fi

    _convert_one_agent "$platform" "$_convert_src" "$_convert_dest"

    echo "Converted: ${_convert_dest#$project_root/}"
    converted=1
  else
    echo "Converting agents from $platform..."
    echo ""

    local src
    for src in "$src_dir"/*; do
      [ -f "$src" ] || continue

      local name="" dest=""

      case "$platform" in
        copilot)
          if [[ "$src" != *.agent.md ]]; then
            continue
          fi
          name=$(basename "$src" .agent.md)
          dest="$_convert_dest_dir/${name}.agent.md"
          ;;
        opencode)
          if [[ "$src" != *.md ]]; then
            continue
          fi
          name=$(basename "$src" .md)
          dest="$_convert_dest_dir/${name}.agent.md"
          ;;
      esac

      if [ -f "$dest" ]; then
        if ! _convert_skip_on_decline "agents/${name}.agent.md"; then
          continue
        fi
      fi

      _convert_one_agent "$platform" "$src" "$dest"

      echo "  + agents/${name}.agent.md"
      converted=$((converted + 1))
    done
  fi

  echo ""
  echo "Converted $converted agent(s) from $platform to $AGENTS_ORCHESTRA_DIR/agents/"
  [ "$converted" -gt 0 ] && echo "Ready to export: run 'orchestra export copilot' or 'orchestra export opencode'"
}