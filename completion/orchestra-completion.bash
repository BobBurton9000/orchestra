_orchestra_completion() {
  local cur prev words cword
  _init_completion -n : || return

  local cmds="install update upgrade remove source list search info export convert generate-manifest help --version"

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
        if [ -f ".orchestra/pkg.lock.yaml" ]; then
          local pkgs
          pkgs="$(yq -r '.packages[] | .name' .orchestra/pkg.lock.yaml 2>/dev/null)"
          COMPREPLY=( $(compgen -W "$pkgs" -- "$cur") )
        fi
        return 0
      fi
      ;;
    source)
      if [ "$cword" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "add list remove" -- "$cur") )
        return 0
      fi
      if [ "$cword" -eq 3 ] && [ "${words[2]}" = "remove" ]; then
        if [ -f ".orchestra/sources.yaml" ]; then
          local srcs
          srcs="$(yq -r '.sources[] | .name' .orchestra/sources.yaml 2>/dev/null)"
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
        COMPREPLY=( $(compgen -W "copilot opencode" -- "$cur") )
        return 0
      fi
      ;;
    remove|info|upgrade)
      if [ "$cword" -eq 2 ] && [ -f ".orchestra/pkg.lock.yaml" ]; then
        local pkgs
        pkgs="$(yq -r '.packages[] | .name' .orchestra/pkg.lock.yaml 2>/dev/null)"
        COMPREPLY=( $(compgen -W "$pkgs" -- "$cur") )
      fi
      ;;
    help)
      if [ "$cword" -eq 2 ]; then
        COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
      fi
      ;;
  esac

  return 0
}

complete -F _orchestra_completion orchestra
[ -n "${BASH_SOURCE[0]:-}" ] && complete -F _orchestra_completion orchestra.sh