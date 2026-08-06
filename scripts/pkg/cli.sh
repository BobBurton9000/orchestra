#!/bin/bash

set -euo pipefail

usage() {
  cat <<EOF
Orchestra — apt-style package manager for agents, prompts, and skills.

Usage: orchestra <command> [args]

Package management:
  install <pkg>[@<source>]       Install a package (silent model if config.yml exists)
  install <pkg> --locked         Install exact SHA recorded in pkg.lock.yaml (npm ci style)
  install --all <source>         Install every package from one specific source
  update                         Refresh all source manifests and HEAD SHAs
  upgrade [pkg]                  Upgrade installed package(s) to current HEAD
  remove <pkg>                   Remove a package (deletes files and lockfile entry)

Sources:
  source add <owner/repo> [name] Add a source to sources.yaml and fetch its manifest
  source list                    Show configured sources
  source remove <name>           Remove a source (refuses if packages still installed)

Query:
  list                           Show installed packages
  list --available               Show all packages across all sources
  search <term>                  Search packages by name/type/path
  info <pkg>                     Show details for a package (installed or available)
  status                         Audit installed files against the package lockfile

Platform compatibility:
  export copilot|opencode        Compile .agents/orchestra/ to platform output
  convert copilot|opencode [name] Convert existing platform files to Orchestra definitions

Publishing (for source authors):
  generate-manifest [dir]        Scan a directory and emit orchestra-source.yaml

Other:
  help [command]                 Show this help, or help for a specific command
  --version                      Show version

Run 'orchestra help <command>' for command-specific help.
EOF
}

help_for() {
  local cmd="$1"
  case "$cmd" in
    install)
      cat <<EOF
orchestra install — install a package from a source

Usage:
  orchestra install <pkg>[@<source>]
  orchestra install <pkg> --locked
  orchestra install --all <source>

Examples:
  orchestra install orchestrator
  orchestra install writing-gherkin
  orchestra install triage-agent@extras
  orchestra install --all core

For agents, the model is read from .orchestra/config.yml silently if present,
otherwise you are prompted and the choice is saved for next time.
EOF
      ;;
    update)
      echo "orchestra update — refresh all source manifests and HEAD SHAs"
      echo "Usage: orchestra update"
      ;;
    upgrade)
      cat <<EOF
orchestra upgrade — upgrade installed package(s) to current HEAD

Usage:
  orchestra upgrade            Upgrade all installed packages
  orchestra upgrade <pkg>      Upgrade a single package
EOF
      ;;
    remove)
      echo "orchestra remove — remove a package (files + lockfile entry)"
      echo "Usage: orchestra remove <pkg>"
      ;;
    source)
      cat <<EOF
orchestra source — manage package sources

Usage:
  orchestra source add <owner/repo> [name]
  orchestra source list
  orchestra source remove <name>

A source is a GitHub repo with an orchestra-source.yaml at its root.
EOF
      ;;
    list)
      echo "orchestra list — show installed or available packages"
      echo "Usage: orchestra list [--available]"
      ;;
    search)
      echo "orchestra search — search packages by name/type/path"
      echo "Usage: orchestra search <term>"
      ;;
    info)
      echo "orchestra info — show details for a package"
      echo "Usage: orchestra info <pkg>"
      ;;
    status)
      cat <<EOF
orchestra status — audit installed files against the package lockfile

Usage: orchestra status

Shows every locked package and its installed paths, then reports files under
.agents/orchestra/ that are missing from the lockfile.
EOF
      ;;
    export)
      echo "orchestra export — compile .agents/orchestra/ to platform output"
      echo "Usage: orchestra export copilot|opencode"
      ;;
    convert)
      cat <<EOF
orchestra convert — convert existing platform files to Orchestra definitions

Usage:
  orchestra convert copilot [name]
  orchestra convert opencode [name]

Without [name], converts all agents from that platform.
Output lands in .agents/orchestra/agents/.
EOF
      ;;
    generate-manifest)
      cat <<EOF
orchestra generate-manifest — scan a directory and emit orchestra-source.yaml

Usage: orchestra generate-manifest [dir]

Defaults to the current directory. Run this in your source repo root after
adding or removing agent/prompt/skill files.
EOF
      ;;
    *)
      usage
      ;;
  esac
}

cmd_source() {
  local sub="${1:-}"
  case "$sub" in
    add)
      local repo="${2:-}"
      local name="${3:-}"
      [ -n "$repo" ] || die "Usage: orchestra source add <owner/repo> [name]"
      gh_check_auth
      sources_ensure_file

      if sources_lookup_name "$repo" >/dev/null 2>&1; then
        local existing_name
        existing_name="$(sources_lookup_name "$repo")"
        die "Repository $repo is already configured as source '$existing_name'."
      fi

      local src_name="${name:-}"
      if [ -z "$src_name" ]; then
        src_name="${repo#*/}"
        src_name="${src_name#orchestra-}"
      fi

      if sources_lookup_repo "$src_name" >/dev/null 2>&1; then
        die "Source name '$src_name' is already in use. Choose a different name: orchestra source add $repo <name>"
      fi

      log_info "Fetching manifest for '$src_name' from $repo..."
      ensure_pkg_dirs
      if ! index_refresh_source "$src_name" "$repo" >/dev/null 2>&1; then
        die "Could not fetch orchestra-source.yaml from $repo. Ensure the repo has one at its root. Source not added."
      fi
      sources_add "$repo" "$name"
      log_info "Source '$src_name' ready."
      ;;
    list)
      sources_cmd_list
      ;;
    remove)
      local name="${2:-}"
      [ -n "$name" ] || die "Usage: orchestra source remove <name>"
      sources_remove "$name"
      ;;
    "")
      die "Usage: orchestra source add|list|remove ..."
      ;;
    *)
      die "Unknown source subcommand: $sub"
      ;;
  esac
}

orchestra_main() {
  local cmd="${1:-}"
  shift || true

  case "$cmd" in
    install)            install_cmd "$@" ;;
    update)             gh_check_auth; ensure_pkg_dirs; index_update_all ;;
    upgrade)            upgrade_cmd "$@" ;;
    remove)             uninstall_cmd "$@" ;;
    source)             cmd_source "$@" ;;
    list)               list_cmd "$@" ;;
    search)             search_cmd "$@" ;;
    info)               info_cmd "$@" ;;
    status)             status_cmd "$@" ;;
    export)             export_cmd "$@" ;;
    convert)            convert_cmd "$@" ;;
    generate-manifest)  manifest_generate "$@" ;;
    help|"")            [ -n "$cmd" ] && [ "$cmd" = "help" ] && help_for "${1:-}" || usage ;;
    --version)          echo "orchestra 1.0.0" ;;
    *)                  die "Unknown command: $cmd. Run 'orchestra help'." ;;
  esac
}
