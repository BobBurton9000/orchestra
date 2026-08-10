#!/usr/bin/env bash

set -euo pipefail

ORCHESTRA_MANIFEST_URL="${ORCHESTRA_MANIFEST_URL:-https://raw.githubusercontent.com/BobBurton9000/orchestra/master/orchestra-manifest.sh}"

SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

declare -A MANIFEST_SEEN=()
declare -a MANIFEST_AGENT_NAMES=()
declare -a MANIFEST_AGENT_PATHS=()
declare -a MANIFEST_PROMPT_NAMES=()
declare -a MANIFEST_PROMPT_PATHS=()
declare -a MANIFEST_PROMPT_DIR_NAMES=()
declare -a MANIFEST_PROMPT_DIR_PATHS=()
declare -a MANIFEST_SKILL_NAMES=()
declare -a MANIFEST_SKILL_PATHS=()
MANIFEST_TOTAL=0

manifest_log() {
  printf '[orchestra-manifest] %s\n' "$*" >&2
}

manifest_die() {
  manifest_log "ERROR: $*"
  exit 1
}

manifest_usage() {
  cat <<'EOF'
Orchestra standalone source manifest generator.

Usage: orchestra-manifest.sh [options] [directory]

The directory defaults to the current working directory. The generated file is
<directory>/orchestra-source.yaml.

Options:
  --check         Check whether orchestra-source.yaml is up to date
  --force         Replace an existing manifest without prompting
  --self-update   Replace this script with the latest copy from Orchestra master
  -h, --help      Show this help

The generator only needs Bash and standard command-line utilities. Self-update
also needs curl or wget.
EOF
}

manifest_yaml_scalar() {
  local value="$1"

  if [[ "$value" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    printf '%s' "$value"
    return
  fi

  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  printf '"%s"' "$value"
}

manifest_add_entry() {
  local group="$1"
  local name="$2"
  local path="$3"

  if [[ -n "${MANIFEST_SEEN[$name]+x}" ]]; then
    manifest_die "Duplicate package name '$name' (paths: ${MANIFEST_SEEN[$name]} and $path)"
  fi
  MANIFEST_SEEN["$name"]="$path"
  MANIFEST_TOTAL=$((MANIFEST_TOTAL + 1))

  case "$group" in
    agent)
      MANIFEST_AGENT_NAMES+=("$name")
      MANIFEST_AGENT_PATHS+=("$path")
      ;;
    prompt)
      MANIFEST_PROMPT_NAMES+=("$name")
      MANIFEST_PROMPT_PATHS+=("$path")
      ;;
    prompt-dir)
      MANIFEST_PROMPT_DIR_NAMES+=("$name")
      MANIFEST_PROMPT_DIR_PATHS+=("$path")
      ;;
    skill)
      MANIFEST_SKILL_NAMES+=("$name")
      MANIFEST_SKILL_PATHS+=("$path")
      ;;
    *)
      manifest_die "Unknown package group: $group"
      ;;
  esac
}

manifest_reset_entries() {
  MANIFEST_SEEN=()
  MANIFEST_AGENT_NAMES=()
  MANIFEST_AGENT_PATHS=()
  MANIFEST_PROMPT_NAMES=()
  MANIFEST_PROMPT_PATHS=()
  MANIFEST_PROMPT_DIR_NAMES=()
  MANIFEST_PROMPT_DIR_PATHS=()
  MANIFEST_SKILL_NAMES=()
  MANIFEST_SKILL_PATHS=()
  MANIFEST_TOTAL=0
}

manifest_relative_path() {
  local target_dir="$1"
  local file_path="$2"
  printf '%s' "${file_path#"$target_dir/"}"
}

manifest_collect_entries() {
  local target_dir="$1"
  local f d filename name rel

  manifest_reset_entries

  if [ -d "$target_dir/agents" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      filename="${f##*/}"
      name="${filename%.agent.md}"
      rel="$(manifest_relative_path "$target_dir" "$f")"
      manifest_add_entry agent "$name" "$rel"
    done < <(find "$target_dir/agents" -maxdepth 1 -type f -name '*.agent.md' -print | LC_ALL=C sort)
  fi

  if [ -d "$target_dir/prompts" ]; then
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      filename="${f##*/}"
      name="${filename%.prompt.md}"
      rel="$(manifest_relative_path "$target_dir" "$f")"
      manifest_add_entry prompt "$name" "$rel"
    done < <(find "$target_dir/prompts" -maxdepth 1 -type f -name '*.prompt.md' -print | LC_ALL=C sort)

    if [ -d "$target_dir/prompts/snippets" ]; then
      manifest_add_entry prompt-dir snippets prompts/snippets/
    fi
  fi

  if [ -d "$target_dir/skills" ]; then
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      [ -f "$d/SKILL.md" ] || continue
      name="${d##*/}"
      rel="$(manifest_relative_path "$target_dir" "$d")/"
      manifest_add_entry skill "$name" "$rel"
    done < <(find "$target_dir/skills" -maxdepth 1 -mindepth 1 -type d -print | LC_ALL=C sort)
  fi
}

manifest_write_entries() {
  local i name path

  if [ "${#MANIFEST_AGENT_NAMES[@]}" -gt 0 ]; then
    printf '  # --- Agents ---\n'
    for i in "${!MANIFEST_AGENT_NAMES[@]}"; do
      name="$(manifest_yaml_scalar "${MANIFEST_AGENT_NAMES[$i]}")"
      path="$(manifest_yaml_scalar "${MANIFEST_AGENT_PATHS[$i]}")"
      printf '  - name: %s\n    type: agent\n    path: %s\n' "$name" "$path"
    done
    printf '\n'
  fi

  if [ "${#MANIFEST_PROMPT_NAMES[@]}" -gt 0 ]; then
    printf '  # --- Prompts ---\n'
    for i in "${!MANIFEST_PROMPT_NAMES[@]}"; do
      name="$(manifest_yaml_scalar "${MANIFEST_PROMPT_NAMES[$i]}")"
      path="$(manifest_yaml_scalar "${MANIFEST_PROMPT_PATHS[$i]}")"
      printf '  - name: %s\n    type: prompt\n    path: %s\n' "$name" "$path"
    done
    printf '\n'
  fi

  if [ "${#MANIFEST_PROMPT_DIR_NAMES[@]}" -gt 0 ]; then
    printf '  # --- Prompt snippets (multi-file package) ---\n'
    for i in "${!MANIFEST_PROMPT_DIR_NAMES[@]}"; do
      name="$(manifest_yaml_scalar "${MANIFEST_PROMPT_DIR_NAMES[$i]}")"
      path="$(manifest_yaml_scalar "${MANIFEST_PROMPT_DIR_PATHS[$i]}")"
      printf '  - name: %s\n    type: prompt-dir\n    path: %s\n' "$name" "$path"
    done
    printf '\n'
  fi

  if [ "${#MANIFEST_SKILL_NAMES[@]}" -gt 0 ]; then
    printf '  # --- Skills ---\n'
    for i in "${!MANIFEST_SKILL_NAMES[@]}"; do
      name="$(manifest_yaml_scalar "${MANIFEST_SKILL_NAMES[$i]}")"
      path="$(manifest_yaml_scalar "${MANIFEST_SKILL_PATHS[$i]}")"
      printf '  - name: %s\n    type: skill\n    path: %s\n' "$name" "$path"
    done
    printf '\n'
  fi

  if [ "$MANIFEST_TOTAL" -eq 0 ]; then
    printf '  # (no agents/, prompts/, or skills/ directories with valid content were found in the source)\n'
  fi
}

manifest_render() {
  local target_dir="$1"
  local output_file="$2"

  manifest_collect_entries "$target_dir"

  {
    printf '%s\n' "# Orchestra source manifest — generated by 'orchestra generate-manifest'"
    printf '%s\n' '# Fields per package: name, type, path'
    printf '%s\n' '# Types: agent | prompt | prompt-dir | skill'
    printf '\npackages:\n'
    manifest_write_entries
  } > "$output_file"
}

manifest_confirm_overwrite() {
  local output_file="$1"

  [ -n "${ORCHESTRA_YES:-}" ] && return 0
  if [ ! -t 0 ]; then
    manifest_die "$output_file already exists; use --force for non-interactive overwrite"
  fi

  local answer
  read -r -p "$output_file already exists. Overwrite? [y/N] " answer
  [[ "${answer,,}" = "y" || "${answer,,}" = "yes" ]]
}

manifest_generate() {
  local target_dir="$1"
  local check="$2"
  local force="$3"
  local output_file temp_file

  [ -d "$target_dir" ] || manifest_die "Directory does not exist: $target_dir"
  target_dir="$(cd "$target_dir" && pwd)"
  output_file="$target_dir/orchestra-source.yaml"

  if [ "$check" -eq 1 ]; then
    temp_file="$(mktemp "$target_dir/.orchestra-source.yaml.check.XXXXXX")"
    manifest_render "$target_dir" "$temp_file"

    if [ ! -f "$output_file" ]; then
      rm -f "$temp_file"
      manifest_die "Manifest is missing: $output_file"
    fi

    if cmp -s "$output_file" "$temp_file"; then
      rm -f "$temp_file"
      manifest_log "Manifest is up to date: $output_file"
      return 0
    fi

    diff -u "$output_file" "$temp_file" >&2 || true
    rm -f "$temp_file"
    manifest_die "Manifest is out of date: $output_file"
  fi

  if [ -f "$output_file" ] && [ "$force" -eq 0 ]; then
    manifest_confirm_overwrite "$output_file" || {
      manifest_log "Skipped."
      return 0
    }
  fi

  temp_file="$(mktemp "$target_dir/.orchestra-source.yaml.XXXXXX")"
  manifest_render "$target_dir" "$temp_file"
  mv "$temp_file" "$output_file"

  manifest_log "Generated $output_file"
  printf '  Packages: %s\n' "$MANIFEST_TOTAL"
}

manifest_download() {
  local destination="$1"

  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --location --output "$destination" "$ORCHESTRA_MANIFEST_URL"
  elif command -v wget >/dev/null 2>&1; then
    wget --quiet --output-document="$destination" "$ORCHESTRA_MANIFEST_URL"
  else
    manifest_die "Self-update requires curl or wget"
  fi
}

manifest_self_update() {
  local script_dir temp_file
  script_dir="$(dirname "$SCRIPT_PATH")"
  [ -w "$script_dir" ] || manifest_die "Cannot update script in non-writable directory: $script_dir"

  temp_file="$(mktemp "$script_dir/.orchestra-manifest.update.XXXXXX")"
  if ! manifest_download "$temp_file" || [ ! -s "$temp_file" ]; then
    rm -f "$temp_file"
    manifest_die "Could not download the latest manifest script from $ORCHESTRA_MANIFEST_URL"
  fi

  if ! bash -n "$temp_file"; then
    rm -f "$temp_file"
    manifest_die "Downloaded manifest script failed Bash syntax validation"
  fi

  chmod +x "$temp_file"
  mv "$temp_file" "$SCRIPT_PATH"
  manifest_log "Updated $SCRIPT_PATH from Orchestra master"
}

manifest_main() {
  local target_dir="."
  local target_seen=0
  local check=0
  local force=0
  local self_update=0
  local original_args=("$@")
  local arg

  while [ "$#" -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
      --check)
        check=1
        ;;
      --force)
        force=1
        ;;
      --self-update)
        self_update=1
        ;;
      -h|--help)
        manifest_usage
        return 0
        ;;
      --)
        [ "$#" -eq 1 ] || manifest_die "Usage: orchestra-manifest.sh [options] [directory]"
        target_dir="$1"
        target_seen=1
        shift
        ;;
      -*)
        manifest_die "Unknown option: $arg"
        ;;
      *)
        [ "$target_seen" -eq 0 ] || manifest_die "Only one source directory may be supplied"
        target_dir="$arg"
        target_seen=1
        ;;
    esac
  done

  if [ "$self_update" -eq 1 ]; then
    manifest_self_update

    local rerun_args=()
    for arg in "${original_args[@]}"; do
      [ "$arg" = "--self-update" ] || rerun_args+=("$arg")
    done
    exec "$SCRIPT_PATH" "${rerun_args[@]}"
  fi

  manifest_generate "$target_dir" "$check" "$force"
}

manifest_main "$@"
