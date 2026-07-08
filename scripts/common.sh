#!/bin/bash

set -euo pipefail

ORCHESTRA_DIR=".orchestra"
AGENTS_ORCHESTRA_DIR=".agents/orchestra"

log_info() {
  printf '[orchestra] %s\n' "$*" >&2
}

log_warn() {
  printf '[orchestra] WARN: %s\n' "$*" >&2
}

log_err() {
  printf '[orchestra] ERROR: %s\n' "$*" >&2
}

die() {
  log_err "$*"
  exit 1
}

read_frontmatter_value() {
  local key="$1"
  local file_path="$2"

  awk -v key="$key" '
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
  ' "$file_path" | tr -d '\r'
}

read_frontmatter_block() {
  local key="$1"
  local file_path="$2"

  awk -v key="$key" '
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
  ' "$file_path"
}

write_body_without_frontmatter() {
  local file_path="$1"

  awk '
    /^---[[:space:]]*$/ {
      marker_count += 1
      next
    }

    marker_count >= 2 {
      print
    }
  ' "$file_path"
}

write_frontmatter() {
  local file_path="$1"

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
  ' "$file_path"
}

normalize_heading_text() {
  local heading="$1"
  echo "$heading" | sed 's/^#*[[:space:]]*//;s/[[:space:]]*$//' | tr -s ' '
}

extract_section() {
  local heading="$1"
  local file_path="$2"
  local normalized
  normalized=$(normalize_heading_text "$heading")

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
  ' "$file_path"
}

validate_heading_exists() {
  local heading="$1"
  local file_path="$2"
  local normalized
  normalized=$(normalize_heading_text "$heading")

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
  ' "$file_path"
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

  die "Could not find .orchestra/ directory. Run from a project with Orchestra installed."
}

parse_include_line_as_vars() {
  local line="$1"
  local out_path_var="$2"
  local out_heading_var="$3"

  if [[ "$line" =~ ^#[[:space:]]*include[[:space:]]+([/~].+)$ ]]; then
    local full_path="${BASH_REMATCH[1]}"

    if [[ "$full_path" =~ ^(.+):(.+)$ ]]; then
      printf -v "$out_path_var" '%s' "${BASH_REMATCH[1]}"
      printf -v "$out_heading_var" '%s' "${BASH_REMATCH[2]}"
    else
      printf -v "$out_path_var" '%s' "$full_path"
      printf -v "$out_heading_var" '%s' ""
    fi
    return 0
  fi
  return 1
}

read_agents_field() {
  local file_path="$1"

  awk '
    /^---[[:space:]]*$/ { m++; next }
    m==1 && /^agents:[[:space:]]/ { print; exit }
  ' "$file_path" | sed 's/^agents:[[:space:]]*//' | tr -d '\r'
}
