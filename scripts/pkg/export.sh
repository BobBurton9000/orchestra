#!/bin/bash

set -euo pipefail

_export_count=0
_export_manifest=""

_export_record_output() {
  _export_manifest="$_export_manifest$1"$'\n'
}

_export_compile_single() {
  local compile_script="$1"
  local project_root="$2"
  local src="$3"
  local dst="$4"
  bash "$compile_script" "$project_root" "$src" "$dst"
}

export_prepare_copilot_agent() {
  local compiled="$1"
  local final="$2"

  local name description model mode
  name=$(read_frontmatter_value name "$compiled")
  description=$(read_frontmatter_value description "$compiled")
  model=$(read_frontmatter_value model "$compiled")
  mode=$(read_frontmatter_value mode "$compiled")

  local agents
  agents=$(read_agents_field "$compiled")

  local body
  body=$(write_body_without_frontmatter "$compiled")

  {
    printf '%s\n' '---'
    [ -n "$name" ] && printf 'name: %s\n' "$name"
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    if [ "$mode" = "subagent" ]; then
      printf 'user-invocable: false\n'
    fi
    [ -n "$agents" ] && printf 'agents: %s\n' "$agents"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    printf '%s\n' '---'
    printf '%s\n' "$body"
  } > "$final"
}

export_prepare_opencode_agent() {
  local compiled="$1"
  local final="$2"

  local description mode model variant permissions
  description=$(read_frontmatter_value description "$compiled")
  mode=$(read_frontmatter_value mode "$compiled")
  model=$(read_frontmatter_value model "$compiled")
  variant=$(read_frontmatter_value variant "$compiled")
  permissions=$(read_frontmatter_block permission "$compiled")

  local body
  body=$(write_body_without_frontmatter "$compiled")

  {
    printf '%s\n' '---'
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    [ -n "$mode" ] && printf 'mode: %s\n' "$mode"
    [ -n "$model" ] && printf 'model: %s\n' "$model"
    [ -n "$variant" ] && printf 'variant: %s\n' "$variant"
    if [ -n "$permissions" ]; then
      printf 'permission:\n'
      printf '%s\n' "$permissions"
    fi
    printf '%s\n' '---'
    printf '%s\n' "$body"
  } > "$final"
}

export_prepare_copilot_prompt() {
  cp "$1" "$2"
}

export_prepare_opencode_prompt() {
  local compiled="$1"
  local final="$2"

  local description agent
  description=$(read_frontmatter_value description "$compiled")
  agent=$(read_frontmatter_value agent "$compiled")

  local body
  body=$(write_body_without_frontmatter "$compiled")

  {
    printf '%s\n' '---'
    [ -n "$description" ] && printf 'description: %s\n' "$description"
    if [ -n "$agent" ] && [ "$agent" != "agent" ]; then
      printf 'agent: %s\n' "$agent"
    fi
    printf '%s\n' '---'
    printf '%s\n' "$body"
  } > "$final"
}

export_process_agents() {
  local platform="$1"
  local project_root="$2"
  local defs_dir="$3"
  local orchestra_temp="$4"
  local compile_script="$5"
  local agents_out="$6"

  local src_dir="$defs_dir/agents"
  [ -d "$src_dir" ] || return 0

  for src_file in "$src_dir/"*.agent.md; do
    [ -f "$src_file" ] || continue

    local name
    name=$(basename "$src_file" .agent.md)
    local compiled="$orchestra_temp/agents/${name}.agent.md"

    _export_compile_single "$compile_script" "$project_root" "$src_file" "$compiled"
    _export_count=$((_export_count + 1))

    case "$platform" in
      copilot)
        local out="$project_root/$agents_out/${name}.agent.md"
        mkdir -p "$(dirname "$out")"
        export_prepare_copilot_agent "$compiled" "$out"
        _export_record_output "$agents_out/${name}.agent.md"
        ;;
      opencode)
        local out="$project_root/$agents_out/${name}.md"
        mkdir -p "$(dirname "$out")"
        export_prepare_opencode_agent "$compiled" "$out"
        _export_record_output "$agents_out/${name}.md"
        ;;
    esac
  done
}

export_process_prompts() {
  local platform="$1"
  local project_root="$2"
  local defs_dir="$3"
  local orchestra_temp="$4"
  local compile_script="$5"
  local prompts_out="$6"

  local src_dir="$defs_dir/prompts"
  [ -d "$src_dir" ] || return 0

  for src_file in "$src_dir/"*.prompt.md; do
    [ -f "$src_file" ] || continue

    local name
    name=$(basename "$src_file" .prompt.md)
    local compiled="$orchestra_temp/prompts/${name}.prompt.md"

    _export_compile_single "$compile_script" "$project_root" "$src_file" "$compiled"
    _export_count=$((_export_count + 1))

    case "$platform" in
      copilot)
        local out="$project_root/$prompts_out/${name}.prompt.md"
        mkdir -p "$(dirname "$out")"
        export_prepare_copilot_prompt "$compiled" "$out"
        _export_record_output "$prompts_out/${name}.prompt.md"
        ;;
      opencode)
        local out="$project_root/$prompts_out/${name}.md"
        mkdir -p "$(dirname "$out")"
        export_prepare_opencode_prompt "$compiled" "$out"
        _export_record_output "$prompts_out/${name}.md"
        ;;
    esac
  done

  local subdir
  for subdir in snippets templates config; do
    local src_sub="$src_dir/$subdir"
    if [ -d "$src_sub" ]; then
      local dst_sub="$project_root/$prompts_out/$subdir"
      mkdir -p "$dst_sub"
      for item in "$src_sub/"*; do
        [ -e "$item" ] || continue
        local item_name
        item_name=$(basename "$item")
        local compiled="$orchestra_temp/prompts/${subdir}_${item_name}"
        _export_compile_single "$compile_script" "$project_root" "$item" "$compiled"
        cp "$compiled" "$dst_sub/$item_name"
        _export_record_output "$prompts_out/$subdir/$item_name"
        _export_count=$((_export_count + 1))
      done
    fi
  done
}

export_process_skills() {
  local project_root="$1"
  local defs_dir="$2"
  local orchestra_temp="$3"
  local compile_script="$4"

  local src_dir="$defs_dir/skills"
  [ -d "$src_dir" ] || return 0

  local skills_out="$project_root/.agents/skills"
  mkdir -p "$skills_out"

  for skill_dir in "$src_dir/"*/; do
    [ -d "$skill_dir" ] || continue

    local skill_name
    skill_name=$(basename "$skill_dir")
    local skill_src="$skill_dir/SKILL.md"
    [ -f "$skill_src" ] || continue

    local compiled="$orchestra_temp/skills/${skill_name}.md"
    _export_compile_single "$compile_script" "$project_root" "$skill_src" "$compiled"

    local dst="$skills_out/$skill_name"
    mkdir -p "$dst"
    cp "$compiled" "$dst/SKILL.md"
    _export_record_output ".agents/skills/$skill_name/SKILL.md"
    _export_count=$((_export_count + 1))

    local companion
    for companion in "$skill_dir"*; do
      [ -f "$companion" ] || continue
      local companion_name
      companion_name=$(basename "$companion")
      [ "$companion_name" = "SKILL.md" ] && continue
      cp "$companion" "$dst/$companion_name"
      _export_record_output ".agents/skills/$skill_name/$companion_name"
      _export_count=$((_export_count + 1))
    done
  done
}

export_cmd() {
  local platform="${1:-}"
  [ -n "$platform" ] || die "Usage: orchestra export copilot|opencode"

  local project_root="$ORCHESTRA_PROJECT_ROOT"
  local orchestra_dir="$project_root/$ORCHESTRA_DIR"
  local orchestra_temp="$orchestra_dir/.temp"
  local compile_script="$SCRIPTS_DIR/compile.sh"
  local defs_dir="$project_root/$AGENTS_ORCHESTRA_DIR"

  local agents_out prompts_out
  case "$platform" in
    copilot)
      agents_out=".github/agents"
      prompts_out=".github/prompts"
      ;;
    opencode)
      agents_out=".opencode/agents"
      prompts_out=".opencode/commands"
      ;;
    *)
      die "Unsupported platform: $platform (use copilot or opencode)"
      ;;
  esac

  if [ ! -d "$defs_dir" ]; then
    die "No definitions found at $AGENTS_ORCHESTRA_DIR. Run 'orchestra install <pkg>' or 'orchestra install --all <source>' first."
  fi

  rm -rf "$orchestra_temp"
  mkdir -p "$orchestra_temp/agents" "$orchestra_temp/prompts" "$orchestra_temp/skills"

  _export_count=0
  _export_manifest=""

  echo "Exporting for $platform..."

  _export_cleanup() { rm -rf "$orchestra_temp"; }
  trap _export_cleanup EXIT

  export_process_agents "$platform" "$project_root" "$defs_dir" "$orchestra_temp" "$compile_script" "$agents_out"
  export_process_prompts "$platform" "$project_root" "$defs_dir" "$orchestra_temp" "$compile_script" "$prompts_out"
  export_process_skills "$project_root" "$defs_dir" "$orchestra_temp" "$compile_script"

  local manifest_file="$orchestra_dir/.manifest"
  printf '%s\n' "$_export_manifest" > "$manifest_file"

  _export_cleanup
  trap - EXIT

  echo ""
  echo "Export complete."
  echo "  Platform: $platform"
  echo "  Compiled: $_export_count files"
  echo "  Manifest: $ORCHESTRA_DIR/.manifest"
}