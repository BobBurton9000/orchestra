_orchestra_completion_project_root() {
  local dir="${ORCHESTRA_PROJECT_ROOT:-$PWD}"
  local state_dir="${ORCHESTRA_DIR:-.orchestra}"

  dir="$(cd "$dir" 2>/dev/null && pwd)" || return 1

  while :; do
    if [ -d "$dir/$state_dir" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    [ "$dir" = "/" ] && return 1
    dir="$(dirname "$dir")"
  done
}

_orchestra_completion() {
  local cur prev words cword
  _init_completion -n : || return

  local cmds="install update upgrade remove fork push source list search info status export convert generate-manifest help --version"

  if [ "$cword" -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi

  local sub="${words[1]}"
  case "$sub" in
    install)
      if [ "$cword" -eq 2 ] && [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--all --locked" -- "$cur") )
        return 0
      fi
      if [ "$cword" -eq 2 ]; then
        local project_root lock_file
        project_root="$(_orchestra_completion_project_root)" || return 0
        lock_file="$project_root/${ORCHESTRA_DIR:-.orchestra}/pkg.lock.yaml"
        if [ -f "$lock_file" ]; then
          local pkgs
          pkgs="$(yq -r '.packages[] | .name' "$lock_file" 2>/dev/null)"
          COMPREPLY=( $(compgen -W "$pkgs" -- "$cur") )
        fi
        return 0
      fi
      ;;
    source)
      if [ "$cword" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "add subscribe unsubscribe list remove" -- "$cur") )
        return 0
      fi
      if [ "$cword" -eq 3 ] && [[ "${words[2]}" == subscribe || "${words[2]}" == unsubscribe || "${words[2]}" == remove ]]; then
        local project_root sources_file
        project_root="$(_orchestra_completion_project_root)" || return 0
        sources_file="$project_root/${ORCHESTRA_DIR:-.orchestra}/sources.yaml"
        if [ -f "$sources_file" ]; then
          local srcs
          srcs="$(yq -r '.sources[] | .name' "$sources_file" 2>/dev/null)"
          COMPREPLY=( $(compgen -W "$srcs" -- "$cur") )
        fi
        return 0
      fi
      ;;
    list)
      if [ "$cword" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "--available -a" -- "$cur") )
        return 0
      fi
      ;;
    export|convert)
      if [ "$cword" -eq 2 ]; then
        local platforms="copilot opencode"
        [ "$sub" = "export" ] && platforms="$platforms pi"
        COMPREPLY=( $(compgen -W "$platforms" -- "$cur") )
        return 0
      fi
      if [ "$sub" = "export" ] && [ "$cword" -eq 3 ]; then
        local categories="agents prompts skills"
        [ "${words[2]}" = "pi" ] && categories="prompts skills"
        COMPREPLY=( $(compgen -W "$categories" -- "$cur") )
        return 0
      fi
      ;;
    remove|fork|info|upgrade|push)
      if [ "$sub" = "push" ] && [ "$cword" -eq 2 ] && [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--dry-run --branch --direct" -- "$cur") )
        return 0
      fi
      if [ "$cword" -eq 2 ]; then
        local project_root lock_file
        project_root="$(_orchestra_completion_project_root)" || return 0
        lock_file="$project_root/${ORCHESTRA_DIR:-.orchestra}/pkg.lock.yaml"
        [ -f "$lock_file" ] || return 0
        local pkgs
        pkgs="$(yq -r '.packages[] | .name' "$lock_file" 2>/dev/null)"
        COMPREPLY=( $(compgen -W "$pkgs" -- "$cur") )
      fi
      if [ "$sub" = "push" ] && [ "$cword" -ge 3 ] && [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--dry-run --branch --direct" -- "$cur") )
      fi
      ;;
    help)
      if [ "$cword" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
      fi
      ;;
    generate-manifest)
      if [ "$cword" -eq 2 ] && [[ "$cur" == --* ]]; then
        COMPREPLY=( $(compgen -W "--check --force --self-update" -- "$cur") )
      fi
      ;;
  esac

  return 0
}

complete -F _orchestra_completion orchestra
[ -n "${BASH_SOURCE[0]:-}" ] && complete -F _orchestra_completion orchestra.sh
