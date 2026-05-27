#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/common.sh"

PROJECT_ROOT="${PROJECT_ROOT:-}"
INCLUDE_STACK=""

push_stack() {
  local f
  f="$(realpath "$1" 2>/dev/null || echo "$1")"
  INCLUDE_STACK="${INCLUDE_STACK:+$INCLUDE_STACK:}$f"
}

pop_stack() {
  INCLUDE_STACK="${INCLUDE_STACK%:*}"
}

on_stack() {
  local f
  f="$(realpath "$1" 2>/dev/null || echo "$1")"
  [[ ":$INCLUDE_STACK:" == *":$f:"* ]]
}

read_file_body() {
  local path="$1"

  if [ ! -f "$path" ]; then
    echo "ERROR: File not found: $path" >&2
    exit 1
  fi

  if write_frontmatter "$path" | grep -q .; then
    write_body_without_frontmatter "$path"
  else
    cat "$path"
  fi
}

read_section_text() {
  local path="$1"
  local heading="$2"

  local body
  body=$(read_file_body "$path")

  echo "$body" | awk -v heading="$heading" '
    BEGIN { in_target = 0; heading_level = 0; target_heading = heading }
    {
      if ($0 ~ /^#{1,6}[[:space:]]/) {
        match($0, /^#{1,6}/)
        level = RLENGTH
        h = substr($0, level + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
        gsub(/[[:space:]]+/, " ", h)

        if (!in_target && h == target_heading) {
          in_target = 1
          heading_level = level
          next
        } else if (in_target && level <= heading_level) {
          exit
        }
      }

      if (in_target) print
    }
  '
}

expand_body() {
  local BODY="$1"

  while IFS= read -r line; do
    local include_path include_heading
    if ! parse_include_line_as_vars "$line" include_path include_heading; then
      echo "$line"
      continue
    fi

    local resolved
    if [[ "$include_path" == "~"* ]]; then
      resolved="${include_path/#\~/$HOME}"
    else
      resolved="$PROJECT_ROOT$include_path"
    fi

    if [ ! -f "$resolved" ]; then
      echo "ERROR: Include file not found: $include_path (resolved: $resolved)" >&2
      exit 1
    fi

    if on_stack "$resolved"; then
      echo "ERROR: Circular include detected: $include_path" >&2
      exit 1
    fi
    push_stack "$resolved"

    echo ""
    if [ -n "$include_heading" ]; then
      local normalized_heading
      normalized_heading=$(normalize_heading_text "$include_heading")

      validate_heading_exists "$normalized_heading" "$resolved" || {
        echo "ERROR: Heading '$include_heading' not found in $include_path" >&2
        exit 1
      }

      local section_text
      section_text=$(read_section_text "$resolved" "$normalized_heading")
      expand_body "$section_text"
    else
      local file_body
      file_body=$(read_file_body "$resolved")
      expand_body "$file_body"
    fi
    echo ""

    pop_stack "$resolved"
  done <<< "$BODY"
}

compile_definition() {
  local SOURCE_FILE="$1"
  local OUTPUT_FILE="$2"

  INCLUDE_STACK=""
  push_stack "$SOURCE_FILE"

  local frontmatter body
  frontmatter=$(write_frontmatter "$SOURCE_FILE")
  body=$(write_body_without_frontmatter "$SOURCE_FILE")

  {
    echo "$frontmatter"
    expand_body "$body"
  } > "$OUTPUT_FILE"
}

if [ -n "${BASH_SOURCE[0]:-}" ] && [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  return 0
fi

if [ $# -lt 3 ]; then
  echo "Usage: compile.sh <project-root> <source-file> <output-file>" >&2
  exit 1
fi

PROJECT_ROOT="$1"
COMPILE_SOURCE="$2"
COMPILE_OUTPUT="$3"

mkdir -p "$(dirname "$COMPILE_OUTPUT")"
rm -f "$COMPILE_OUTPUT"
compile_definition "$COMPILE_SOURCE" "$COMPILE_OUTPUT"
