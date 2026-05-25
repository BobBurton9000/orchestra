#!/bin/bash

set -euo pipefail

ORCHESTRA_DIR=".orchestra"
AGENTS_ORCHESTRA_DIR=".agents/orchestra"

read_frontmatter_value() {
  local KEY=$1
  local FILE_PATH=$2

  awk -v key="$KEY" '
    BEGIN { in_frontmatter = 0 }

    /^---[[:space:]]*$/ {
      if (in_frontmatter == 0) {
        in_frontmatter = 1
        next
      }
      exit
    }

    in_frontmatter == 1 {
      pattern = "^" key ":[[:space:]]*"
      if ($0 ~ pattern) {
        sub(pattern, "", $0)
        print
        exit
      }
    }
  ' "$FILE_PATH" | tr -d '\r'
}

read_frontmatter_block() {
  local KEY=$1
  local FILE_PATH=$2

  awk -v key="$KEY" '
    BEGIN { in_frontmatter = 0; in_block = 0 }

    /^---[[:space:]]*$/ {
      if (in_frontmatter == 0) {
        in_frontmatter = 1
        next
      }
      exit
    }

    in_frontmatter == 1 {
      pattern = "^" key ":[[:space:]]*$"
      if ($0 ~ pattern) {
        in_block = 1
        next
      }
      if (in_block == 1) {
        if (/^[[:space:]]/)
          print
        else
          in_block = 0
      }
    }
  ' "$FILE_PATH"
}

write_body_without_frontmatter() {
  local FILE_PATH=$1

  awk '
    /^---[[:space:]]*$/ {
      marker_count += 1
      next
    }

    marker_count >= 2 {
      print
    }
  ' "$FILE_PATH"
}

write_frontmatter() {
  local FILE_PATH=$1

  awk '
    /^---[[:space:]]*$/ {
      marker_count += 1
      if (marker_count == 1) {
        print
        next
      }
      if (marker_count == 2) {
        print
        exit
      }
    }

    marker_count == 1 {
      print
    }
  ' "$FILE_PATH"
}

normalize_heading_text() {
  local heading="$1"
  echo "$heading" | sed 's/^#*[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' '
}

extract_section() {
  local HEADING="$1"
  local FILE_PATH="$2"
  local normalized
  normalized=$(normalize_heading_text "$HEADING")

  awk -v heading="$normalized" '
    BEGIN { in_target = 0; heading_level = 0 }
    {
      if ($0 ~ /^#{1,6}[[:space:]]/) {
        match($0, /^#{1,6}/)
        level = RLENGTH
        line_heading = substr($0, level + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line_heading)
        gsub(/[[:space:]]+/, " ", line_heading)

        if (!in_target && line_heading == heading) {
          in_target = 1
          heading_level = level
          next
        } else if (in_target && level <= heading_level) {
          exit
        }
      }

      if (in_target) {
        print
      }
    }
  ' "$FILE_PATH"
}

validate_heading_exists() {
  local HEADING="$1"
  local FILE_PATH="$2"
  local normalized
  normalized=$(normalize_heading_text "$HEADING")

  awk -v heading="$normalized" '
    {
      if ($0 ~ /^#{1,6}[[:space:]]/) {
        match($0, /^#{1,6}/)
        level = RLENGTH
        line_heading = substr($0, level + 1)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", line_heading)
        gsub(/[[:space:]]+/, " ", line_heading)
        if (line_heading == heading) {
          found = 1
          exit
        }
      }
    }
    END {
      if (!found) exit 1
    }
  ' "$FILE_PATH"
}

resolve_model_value() {
  local VALUE=$1
  local ORCHESTRATOR_MODEL="${2-}"
  local SUBAGENT_MODEL="${3-}"

  case "$VALUE" in
    '${ORCHESTRATOR_MODEL}')
      printf '%s\n' "$ORCHESTRATOR_MODEL"
      ;;
    '${SUBAGENT_MODEL}')
      printf '%s\n' "$SUBAGENT_MODEL"
      ;;
    *)
      printf '%s\n' "$VALUE"
      ;;
  esac
}

detect_project_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[1]:-$0}")" && pwd)"

  while [ "$dir" != "/" ]; do
    if [ -d "$dir/$ORCHESTRA_DIR" ]; then
      echo "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done

  echo "ERROR: Could not find .orchestra/ directory. Run from a project with Orchestra installed." >&2
  exit 1
}

parse_include_line_as_vars() {
  local LINE="$1"
  local OUT_PATH_VAR="$2"
  local OUT_HEADING_VAR="$3"

  if [[ "$LINE" =~ ^#[[:space:]]*include[[:space:]]+([/~].+)$ ]]; then
    local full_path="${BASH_REMATCH[1]}"

    if [[ "$full_path" =~ ^(.+):(.+)$ ]]; then
      printf -v "$OUT_PATH_VAR" '%s' "${BASH_REMATCH[1]}"
      printf -v "$OUT_HEADING_VAR" '%s' "${BASH_REMATCH[2]}"
    else
      printf -v "$OUT_PATH_VAR" '%s' "$full_path"
      printf -v "$OUT_HEADING_VAR" '%s' ""
    fi
    return 0
  fi
  return 1
}
