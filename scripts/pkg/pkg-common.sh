#!/bin/bash

set -euo pipefail

ORCHESTRA_DIR="${ORCHESTRA_DIR:-.orchestra}"
AGENTS_ORCHESTRA_DIR="${AGENTS_ORCHESTRA_DIR:-.agents/orchestra}"

if [ -n "${ORCHESTRA_PROJECT_ROOT:-}" ]; then
  PKG_SOURCES_FILE="$ORCHESTRA_PROJECT_ROOT/$ORCHESTRA_DIR/sources.yaml"
  PKG_LOCK_FILE="$ORCHESTRA_PROJECT_ROOT/$ORCHESTRA_DIR/pkg.lock.yaml"
  PKG_CACHE_DIR="$ORCHESTRA_PROJECT_ROOT/$ORCHESTRA_DIR/pkg-cache"
  PKG_CONFIG_FILE="$ORCHESTRA_PROJECT_ROOT/$ORCHESTRA_DIR/config.yml"
  AGENTS_ORCHESTRA_DIR_ABS="$ORCHESTRA_PROJECT_ROOT/$AGENTS_ORCHESTRA_DIR"
else
  PKG_SOURCES_FILE="$ORCHESTRA_DIR/sources.yaml"
  PKG_LOCK_FILE="$ORCHESTRA_DIR/pkg.lock.yaml"
  PKG_CACHE_DIR="$ORCHESTRA_DIR/pkg-cache"
  PKG_CONFIG_FILE="$ORCHESTRA_DIR/config.yml"
  AGENTS_ORCHESTRA_DIR_ABS="$AGENTS_ORCHESTRA_DIR"
fi

LF=$'\n'
TAB=$'\t'
PIPE='|'

ensure_orchestra_dir() {
  [ -d "$ORCHESTRA_DIR" ] || die "No $ORCHESTRA_DIR/ directory here. Run this from a project with Orchestra installed."
}

ensure_pkg_dirs() {
  ensure_orchestra_dir
  mkdir -p "$PKG_CACHE_DIR"
}

ask_yes_no() {
  local prompt="$1"
  if [ -n "${ORCHESTRA_YES:-}" ]; then
    return 0
  fi
  local answer
  read -rp "$prompt [y/N] " answer
  [ "${answer,,}" = "y" ] || [ "${answer,,}" = "yes" ]
}

ask_overwrite() {
  ask_yes_no "$1 already exists. Overwrite?"
}

ask_remove() {
  ask_yes_no "Remove $1?"
}

ensure_file() {
  local f="$1"
  [ -f "$f" ] || die "Required file missing: $f"
}

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

canonical_type_for_install() {
  local type="$1"
  case "$type" in
    agent) printf 'agents' ;;
    prompt|prompt-dir) printf 'prompts' ;;
    skill) printf 'skills' ;;
    *) printf '' ;;
  esac
}