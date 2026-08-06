#!/bin/bash

set -euo pipefail

lock_read_field() {
  local pkg="$1"
  local field_idx="$2"
  [ -f "$PKG_LOCK_FILE" ] || return 1
  local field_name
  case "$field_idx" in
    1) field_name="name" ;;
    2) field_name="source" ;;
    3) field_name="type" ;;
    4) field_name="sha" ;;
    5) field_name="paths" ;;
    *) return 1 ;;
  esac
  local val
  val="$(yaml_lock_field "$PKG_LOCK_FILE" "$pkg" "$field_name" 2>/dev/null || true)"
  [ -n "$val" ] || return 1
  printf '%s\n' "$val"
}

lock_is_installed() {
  local pkg="$1"
  [ -f "$PKG_LOCK_FILE" ] || return 1
  yaml_lock_is_installed "$PKG_LOCK_FILE" "$pkg"
}

lock_get_source() { lock_read_field "$1" 2; }
lock_get_type() { lock_read_field "$1" 3; }
lock_get_sha() { lock_read_field "$1" 4; }
lock_get_paths() { lock_read_field "$1" 5; }

lock_remove_entry() {
  local pkg="$1"
  [ -f "$PKG_LOCK_FILE" ] || return 0
  yaml_lock_remove_entry "$PKG_LOCK_FILE" "$pkg"
}

lock_write_entry() {
  local pkg="$1"
  local source="$2"
  local type="$3"
  local sha="$4"
  shift 4
  local paths=("$@")

  if [ ! -f "$PKG_LOCK_FILE" ]; then
    {
      echo "# Orchestra package lockfile — personal, not checked in."
      echo "packages: []"
    } > "$PKG_LOCK_FILE"
  fi

  local paths_array=()
  local p
  for p in "${paths[@]}"; do
    [ -n "$p" ] || continue
    paths_array+=("$p")
  done

  if [ ${#paths_array[@]} -eq 0 ]; then
    paths_array=("")
  fi

  yaml_lock_write_entry "$PKG_LOCK_FILE" "$pkg" "$source" "$type" "$sha" "${paths_array[@]}"
}

config_get_default_model() {
  local kind="$1"
  [ -f "$PKG_CONFIG_FILE" ] || return 1
  local val
  val="$(awk -v k="$kind" '
    $0 ~ "^" k ":[[:space:]]" { sub("^" k ":[[:space:]]*", ""); print; exit }
  ' "$PKG_CONFIG_FILE" | tr -d '\r')"
  [ -n "$val" ] && printf '%s\n' "$val"
}

config_save_models() {
  local orch_model="$1"
  local sub_model="$2"
  ensure_orchestra_dir
  cat > "$PKG_CONFIG_FILE" <<EOF
orchestrator: $orch_model
subagent: $sub_model
EOF
}

config_ensure_for_install() {
  if [ ! -f "$PKG_CONFIG_FILE" ]; then
    log_info "No $PKG_CONFIG_FILE found. Let's set your default models."
    read -rp "Default model for the orchestrator agent: " ORCH_MODEL
    [ -n "$ORCH_MODEL" ] || die "No orchestrator model specified."
    read -rp "Default model for all subagents: " SUB_MODEL
    [ -n "$SUB_MODEL" ] || die "No subagent model specified."
    config_save_models "$ORCH_MODEL" "$SUB_MODEL"
    log_info "Saved model defaults to $PKG_CONFIG_FILE"
  fi
}

resolve_model_for_agent() {
  local agent_name="$1"
  local template_path="$2"
  local existing_model="${3:-}"

  if [ -n "$existing_model" ]; then
    printf '%s\n' "$existing_model"
    return
  fi

  if [ ! -f "$PKG_CONFIG_FILE" ]; then
    config_ensure_for_install
  fi

  local kind default_model
  if [ "$agent_name" = "orchestrator" ]; then
    kind="orchestrator"
  else
    kind="subagent"
  fi

  default_model="$(config_get_default_model "$kind" || true)"

  if [ -n "$default_model" ]; then
    printf '%s\n' "$default_model"
    return
  fi

  local prompt_txt="[${kind} default: (none)]"

  read -rp "Model for '$agent_name' ${prompt_txt}: " model_input
  [ -n "$model_input" ] || die "No model specified."

  printf '%s\n' "$model_input"
}

inject_model_in_frontmatter() {
  local src_file="$1"
  local model="$2"
  local out_file="$3"

  awk -v model="$model" '
    BEGIN { injected = 0; marker_count = 0 }
    /^---[[:space:]]*$/ {
      marker_count++
      if (marker_count == 2 && !injected) { print "model: " model; injected = 1 }
      print
      next
    }
    /^model:[[:space:]]/ { print "model: " model; injected = 1; next }
    { print }
  ' "$src_file" > "$out_file"
}

fetch_dir_files() {
  local source_repo="$1"
  local strip_path="$2"
  local sha="$3"
  local target_dir="$4"
  local path_prefix="$5"
  local pkg_name="$6"
  local -n fetch_installed_ref="$7"

  local filenames
  filenames="$(gh_list_dir "$source_repo" "$strip_path" "$sha")"
  [ -n "$filenames" ] || die "No files in $strip_path from $source_repo@$sha"

  local fname
  while IFS= read -r fname; do
    [ -n "$fname" ] || continue
    [[ "$fname" == .* ]] && continue
    local file_raw
    file_raw="$(gh_fetch_file_raw "$source_repo" "${strip_path}/${fname}" "$sha")"
    printf '%s\n' "$file_raw" > "$target_dir/$fname"
    fetch_installed_ref+=("${path_prefix}/${pkg_name}/${fname}")
  done <<< "$filenames"
}

install_agent_file() {
  local source_repo="$1" pkg_path="$2" sha="$3" target_base="$4" pkg_name="$5"
  local -n agent_installed_ref="$6"
  local existing_model="${7:-}"
  local overwrite="${8:-0}"
  local target="$target_base/${pkg_name}.agent.md"
  if [ -f "$target" ]; then
    if [ "$overwrite" -eq 1 ]; then
      log_info "Overwriting agents/${pkg_name}.agent.md (upgrade)."
    else
      ask_overwrite "agents/${pkg_name}.agent.md" || { log_info "Skipped $pkg_name."; return 1; }
    fi
  fi
  mkdir -p "$target_base"

  local raw tmp_raw
  raw="$(gh_fetch_file_raw "$source_repo" "$pkg_path" "$sha")"
  [ -n "$raw" ] || die "Failed to fetch $pkg_path from $source_repo@$sha"
  tmp_raw="$(mktemp)"
  printf '%s\n' "$raw" > "$tmp_raw"

  local agent_name
  agent_name="$(read_frontmatter_value name "$tmp_raw" 2>/dev/null || echo "$pkg_name")"
  [ -n "$agent_name" ] || agent_name="$pkg_name"

  local model
  model="$(resolve_model_for_agent "$agent_name" "$tmp_raw" "$existing_model")"

  inject_model_in_frontmatter "$tmp_raw" "$model" "$target"
  rm -f "$tmp_raw"
  agent_installed_ref+=("agents/${pkg_name}.agent.md")
  log_info "Installed agent '$pkg_name' (model: $model) -> $target"
}

install_prompt_file() {
  local source_repo="$1" pkg_path="$2" sha="$3" target_base="$4" pkg_name="$5"
  local -n prompt_installed_ref="$6"
  local overwrite="${7:-0}"
  local target="$target_base/${pkg_name}.prompt.md"
  if [ -f "$target" ]; then
    if [ "$overwrite" -eq 1 ]; then
      log_info "Overwriting prompts/${pkg_name}.prompt.md (upgrade)."
    else
      ask_overwrite "prompts/${pkg_name}.prompt.md" || { log_info "Skipped $pkg_name."; return 1; }
    fi
  fi
  mkdir -p "$target_base"

  local raw
  raw="$(gh_fetch_file_raw "$source_repo" "$pkg_path" "$sha")"
  [ -n "$raw" ] || die "Failed to fetch $pkg_path from $source_repo@$sha"

  printf '%s\n' "$raw" > "$target"
  prompt_installed_ref+=("prompts/${pkg_name}.prompt.md")
  log_info "Installed prompt '$pkg_name' -> $target"
}

install_prompt_dir() {
  local source_repo="$1" pkg_path="$2" sha="$3" target_base="$4" pkg_name="$5"
  local -n pdir_installed_ref="$6"
  local overwrite="${7:-0}"
  local target="$target_base/${pkg_name}"
  if [ -d "$target" ]; then
    if [ "$overwrite" -eq 1 ]; then
      log_info "Overwriting prompts/${pkg_name}/ (upgrade)."
    else
      ask_overwrite "prompts/${pkg_name}/" || { log_info "Skipped $pkg_name."; return 1; }
    fi
  fi
  mkdir -p "$target"

  fetch_dir_files "$source_repo" "${pkg_path%/}" "$sha" "$target" "prompts" "$pkg_name" pdir_installed_ref
  log_info "Installed prompt-dir '$pkg_name' (${#pdir_installed_ref[@]} files) -> $target"
}

install_skill_dir() {
  local source_repo="$1" pkg_path="$2" sha="$3" target_base="$4" pkg_name="$5"
  local -n skill_installed_ref="$6"
  local overwrite="${7:-0}"
  local target="$target_base/${pkg_name}"
  if [ -d "$target" ]; then
    if [ "$overwrite" -eq 1 ]; then
      log_info "Overwriting skills/${pkg_name}/ (upgrade)."
    else
      ask_overwrite "skills/${pkg_name}/" || { log_info "Skipped $pkg_name."; return 1; }
    fi
  fi
  mkdir -p "$target"

  fetch_dir_files "$source_repo" "${pkg_path%/}" "$sha" "$target" "skills" "$pkg_name" skill_installed_ref
  log_info "Installed skill '$pkg_name' (${#skill_installed_ref[@]} files) -> $target"
}

install_files_for_package() {
  local source_name="$1"
  local source_repo="$2"
  local pkg_type="$3"
  local pkg_path="$4"
  local sha="$5"
  local pkg_name="$6"
  local existing_model="${7:-}"
  local overwrite="${8:-0}"

  local ns
  ns="$(canonical_type_for_install "$pkg_type")"
  [ -n "$ns" ] || die "Unknown package type: $pkg_type"

  local target_base="$AGENTS_ORCHESTRA_DIR_ABS/$ns"
  local installed_paths=()

  case "$pkg_type" in
    agent)
      install_agent_file "$source_repo" "$pkg_path" "$sha" "$target_base" "$pkg_name" installed_paths "$existing_model" "$overwrite" || return 1
      ;;
    prompt)
      install_prompt_file "$source_repo" "$pkg_path" "$sha" "$target_base" "$pkg_name" installed_paths "$overwrite" || return 1
      ;;
    prompt-dir)
      install_prompt_dir "$source_repo" "$pkg_path" "$sha" "$target_base" "$pkg_name" installed_paths "$overwrite" || return 1
      ;;
    skill)
      install_skill_dir "$source_repo" "$pkg_path" "$sha" "$target_base" "$pkg_name" installed_paths "$overwrite" || return 1
      ;;
    *)
      die "Unknown package type: $pkg_type"
      ;;
  esac

  local i
  for i in "${!installed_paths[@]}"; do
    printf '%s\n' "${installed_paths[$i]}"
  done
}

package_install_target() {
  local pkg_type="$1"
  local pkg_name="$2"

  case "$pkg_type" in
    agent)      printf '%s/agents/%s.agent.md\n' "$AGENTS_ORCHESTRA_DIR_ABS" "$pkg_name" ;;
    prompt)     printf '%s/prompts/%s.prompt.md\n' "$AGENTS_ORCHESTRA_DIR_ABS" "$pkg_name" ;;
    prompt-dir) printf '%s/prompts/%s\n' "$AGENTS_ORCHESTRA_DIR_ABS" "$pkg_name" ;;
    skill)      printf '%s/skills/%s\n' "$AGENTS_ORCHESTRA_DIR_ABS" "$pkg_name" ;;
    *)           return 1 ;;
  esac
}

package_install_target_exists() {
  local target
  target="$(package_install_target "$1" "$2")"
  [ -e "$target" ]
}

install_one_package() {
  local pkg_spec="$1"
  local use_locked="${2:-0}"

  gh_check_auth
  ensure_pkg_dirs

  local pkg_name source_filter=""
  if [[ "$pkg_spec" == *@* ]]; then
    pkg_name="${pkg_spec%@*}"
    source_filter="${pkg_spec#*@}"
  else
    pkg_name="$pkg_spec"
  fi

  local found=""
  found="$(index_find_package "$pkg_name" "$source_filter" || true)"

  if [ -z "$found" ]; then
    if [ -n "$source_filter" ]; then
      if ! index_ensure_cached "$source_filter"; then
        local repo
        repo="$(sources_lookup_repo "$source_filter" || true)"
        [ -n "$repo" ] || die "No source named '$source_filter'. Run 'orchestra source list'."
        log_info "Caching source '$source_filter'..."
        index_refresh_source "$source_filter" "$repo" >/dev/null
        found="$(index_find_package "$pkg_name" "$source_filter" || true)"
      fi
    else
      local any_cached=0
      _install_check_cached() {
        if index_ensure_cached "$1"; then
          any_cached=1
          return 1
        fi
      }
      yaml_sources_each "$PKG_SOURCES_FILE" _install_check_cached || true

      if [ "$any_cached" -eq 0 ]; then
        log_info "Cache is cold. Running 'orchestra update'..."
        index_update_all >/dev/null
        found="$(index_find_package "$pkg_name" || true)"
      fi
    fi
  fi

  [ -n "$found" ] || {
    if [ -n "$source_filter" ]; then
      die "Package '$pkg_name' not found in source '$source_filter'. Run 'orchestra update' to refresh indexes."
    else
      die "Package '$pkg_name' not found in any cached source. Run 'orchestra update' to refresh indexes."
    fi
  }

  local source_name source_repo pkg_type pkg_path
  IFS=$'\t' read -r source_name source_repo pkg_type pkg_path <<< "$found"

  local sha
  if [ "$use_locked" -eq 1 ]; then
    sha="$(lock_get_sha "$pkg_name" 2>/dev/null || true)"
    [ -n "$sha" ] || die "No locked SHA for '$pkg_name'. Run without --locked or 'orchestra install $pkg_name' first."
    log_info "Installing $pkg_name at locked SHA $sha"
  else
    sha="$(index_get_sha "$source_name")"
    [ -n "$sha" ] || die "No cached HEAD sha for source '$source_name'. Run 'orchestra update'."
  fi

  local installed_paths_out
  installed_paths_out="$(install_files_for_package "$source_name" "$source_repo" "$pkg_type" "$pkg_path" "$sha" "$pkg_name")" || {
    log_info "Install cancelled for $pkg_name."
    return 1
  }

  local installed_paths=()
  while IFS= read -r p; do
    [ -n "$p" ] || continue
    installed_paths+=("$p")
  done <<< "$installed_paths_out"

  if [ ${#installed_paths[@]} -eq 0 ]; then
    installed_paths=("")
  fi

  lock_write_entry "$pkg_name" "$source_name" "$pkg_type" "$sha" "${installed_paths[@]}"
  log_info "Locked $pkg_name @ ${sha:0:12}"
}

install_all_from_source() {
  local source_name="$1"

  gh_check_auth
  ensure_pkg_dirs
  sources_ensure_file

  local source_repo
  source_repo="$(sources_lookup_repo "$source_name" || true)"
  [ -n "$source_repo" ] || die "No source named '$source_name'. Run 'orchestra source list'."

  if ! index_ensure_cached "$source_name"; then
    log_info "Caching source '$source_name'..."
    index_refresh_source "$source_name" "$source_repo" >/dev/null
  fi

  local sha
  sha="$(index_get_sha "$source_name")"
  [ -n "$sha" ] || die "No cached HEAD sha for '$source_name'. Run 'orchestra update'."

  local count=0 skipped=0
  _install_all_one() {
    local pkg_name="$1" pkg_type="$2" pkg_path="$3"
    if install_one_package "${pkg_name}@${source_name}" 0 >/dev/null 2>&1; then
      count=$((count + 1))
      echo "  + $pkg_name"
    else
      skipped=$((skipped + 1))
    fi
  }
  local tsv_line tsv_fields=()
  while IFS= read -r tsv_line; do
    [ -n "$tsv_line" ] || continue
    IFS=$'\t' read -r -a tsv_fields <<< "$tsv_line"
    [ "${#tsv_fields[@]}" -ge 3 ] || continue
    _install_all_one "${tsv_fields[@]}"
  done < <(index_list_packages_in_source "$source_name")

  echo ""
  log_info "Installed $count package(s) from '$source_name' ($skipped skipped) @ ${sha:0:12}"
}

install_cmd() {
  local arg="${1:-}"
  case "$arg" in
    --all)
      local src="${2:-}"
      [ -n "$src" ] || die "Usage: orchestra install --all <source>"
      install_all_from_source "$src"
      ;;
    "")
      die "Usage: orchestra install <pkg>[@<source>] | --all <source>"
      ;;
    *)
      local use_locked=0
      local pkg="$arg"
      if [ "${2:-}" = "--locked" ]; then
        use_locked=1
      elif [ -n "${2:-}" ]; then
        die "Unknown argument: $2"
      fi
      install_one_package "$pkg" "$use_locked"
      ;;
  esac
}
