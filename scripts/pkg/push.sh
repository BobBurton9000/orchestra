#!/bin/bash

set -euo pipefail

push_validate_relative_path() {
  local path="$1"
  local label="$2"

  [ -n "$path" ] || die "$label is empty."
  case "$path" in
    /*|.|./*|../*|*/../*|*/..)
      die "Unsafe relative path for $label: $path"
      ;;
  esac
}

push_validate_checkout_path() {
  local checkout="$1"
  local relative_path="$2"
  local current="$checkout"
  local component
  local path_parts=()

  IFS='/' read -r -a path_parts <<< "$relative_path"
  for component in "${path_parts[@]}"; do
    [ -n "$component" ] || continue
    current="$current/$component"
    [ ! -L "$current" ] || die "Source path contains a symlink: $relative_path"
  done
}

push_strip_agent_model() {
  local source_file="$1"
  local output_file="$2"
  local marker_count

  marker_count="$(awk '/^---[[:space:]]*$/ { count++ } END { print count + 0 }' "$source_file")"
  [ "$marker_count" -ge 2 ] || die "Agent '$source_file' has invalid frontmatter; refusing to push it."

  awk '
    /^---[[:space:]]*$/ {
      marker_count++
      print
      next
    }
    marker_count == 1 && /^model:[[:space:]]/ { next }
    { print }
  ' "$source_file" > "$output_file"
}

push_resolve_provenance() {
  local pkg="$1"
  local source source_repo configured_repo stored_repo pkg_type locked_sha source_path

  source="$(lock_get_source "$pkg")"
  pkg_type="$(lock_get_type "$pkg")"
  locked_sha="$(lock_get_sha "$pkg")"
  stored_repo="$(lock_get_source_repo "$pkg" 2>/dev/null || true)"
  configured_repo="$(sources_lookup_repo "$source" 2>/dev/null || true)"

  if [ -n "$stored_repo" ] && [ -n "$configured_repo" ] && [ "$stored_repo" != "$configured_repo" ]; then
    die "Source '$source' now points to '$configured_repo', but '$pkg' was installed from '$stored_repo'. Refusing to push."
  fi

  source_repo="${stored_repo:-$configured_repo}"
  [ -n "$source_repo" ] || die "Cannot resolve the source repository for '$pkg'. Re-add source '$source' or reinstall the package."
  [[ "$source_repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] ||
    die "Invalid GitHub source repository for '$pkg': $source_repo"

  source_path="$(lock_get_source_path "$pkg" 2>/dev/null || true)"
  if [ -z "$source_path" ]; then
    local manifest_file found manifest_pkg manifest_type manifest_path
    manifest_file="$(mktemp)"
    if ! gh_fetch_manifest "$source_repo" "$locked_sha" > "$manifest_file" || [ ! -s "$manifest_file" ]; then
      rm -f "$manifest_file"
      die "Could not recover the source manifest for '$pkg' at $locked_sha. Refusing to guess its source path."
    fi
    found="$(yaml_manifest_find "$manifest_file" "$pkg" || true)"
    rm -f "$manifest_file"
    [ -n "$found" ] || die "Package '$pkg' is not present in the source manifest at $locked_sha. Refusing to guess its source path."
    IFS=$'\t' read -r manifest_pkg manifest_type manifest_path <<< "$found"
    [ "$manifest_type" = "$pkg_type" ] ||
      die "Package '$pkg' changed type between the lockfile and source manifest at $locked_sha."
    source_path="$manifest_path"
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "$source" "$source_repo" "$pkg_type" "$locked_sha" "$source_path"
}

push_collect_paths() {
  local pkg="$1"
  local pkg_type="$2"
  local source_path="$3"
  local local_paths_name="$4"
  local source_paths_name="$5"
  local -n local_paths_ref="$local_paths_name"
  local -n source_paths_ref="$source_paths_name"
  local lock_path local_prefix source_base suffix
  local package_dir=""
  declare -A expected_paths=()

  case "$pkg_type" in
    agent)
      local_prefix="agents/${pkg}.agent.md"
      [[ "$source_path" != */ ]] || die "Agent '$pkg' has a directory source path: $source_path"
      source_base="$source_path"
      ;;
    prompt)
      local_prefix="prompts/${pkg}.prompt.md"
      [[ "$source_path" != */ ]] || die "Prompt '$pkg' has a directory source path: $source_path"
      source_base="$source_path"
      ;;
    prompt-dir)
      local_prefix="prompts/${pkg}/"
      source_base="${source_path%/}"
      package_dir="$AGENTS_ORCHESTRA_DIR_ABS/prompts/${pkg}"
      ;;
    skill)
      local_prefix="skills/${pkg}/"
      source_base="${source_path%/}"
      package_dir="$AGENTS_ORCHESTRA_DIR_ABS/skills/${pkg}"
      ;;
    *)
      die "Unknown package type for '$pkg': $pkg_type"
      ;;
  esac

  push_validate_relative_path "$source_base" "source path for '$pkg'"

  while IFS= read -r lock_path; do
    [ -n "$lock_path" ] || continue
    push_validate_relative_path "$lock_path" "locked path for '$pkg'"

    case "$pkg_type" in
      agent|prompt)
        [ "$lock_path" = "$local_prefix" ] ||
          die "Lockfile path '$lock_path' does not match package '$pkg'."
        source_paths_ref+=("$source_base")
        ;;
      prompt-dir|skill)
        [[ "$lock_path" == "$local_prefix"* ]] ||
          die "Lockfile path '$lock_path' does not match package '$pkg'."
        suffix="${lock_path#"$local_prefix"}"
        [ -n "$suffix" ] || die "Lockfile path '$lock_path' has no file name."
        push_validate_relative_path "$suffix" "file path for '$pkg'"
        source_paths_ref+=("$source_base/$suffix")
        ;;
    esac

    local_paths_ref+=("$lock_path")
    expected_paths["$lock_path"]=1
  done < <(yaml_lock_paths_lines "$PKG_LOCK_FILE" "$pkg")

  [ "${#local_paths_ref[@]}" -gt 0 ] || die "Package '$pkg' has no locked files to push."

  case "$pkg_type" in
    agent|prompt)
      [ "${#local_paths_ref[@]}" -eq 1 ] || die "Package '$pkg' has unexpected extra locked files."
      ;;
    prompt-dir|skill)
      [ -d "$package_dir" ] || die "Package directory is missing for '$pkg': $package_dir"
      local absolute_path relative_path
      while IFS= read -r -d '' absolute_path; do
        relative_path="${absolute_path#"$AGENTS_ORCHESTRA_DIR_ABS/"}"
        if [ -z "${expected_paths[$relative_path]+set}" ]; then
          die "Package '$pkg' contains untracked file '$relative_path'. Push supports existing locked files only."
        fi
      done < <(find "$package_dir" \( -type f -o -type l \) -print0)
      ;;
  esac
}

push_check_manifest_mapping() {
  local checkout="$1"
  local pkg="$2"
  local pkg_type="$3"
  local source_path="$4"
  local work_dir="$5"
  local manifest_file found manifest_pkg manifest_type manifest_path expected_path actual_path

  manifest_file="$work_dir/current-manifest.yaml"
  if ! git -C "$checkout" show "HEAD:orchestra-source.yaml" > "$manifest_file" 2>/dev/null; then
    die "Source '$checkout' has no orchestra-source.yaml at current HEAD."
  fi

  found="$(yaml_manifest_find "$manifest_file" "$pkg" || true)"
  [ -n "$found" ] || die "Package '$pkg' is missing from the source manifest at current HEAD."
  IFS=$'\t' read -r manifest_pkg manifest_type manifest_path <<< "$found"
  [ "$manifest_type" = "$pkg_type" ] ||
    die "Package '$pkg' changed type in the source manifest."

  expected_path="$source_path"
  actual_path="$manifest_path"
  case "$pkg_type" in
    prompt-dir|skill)
      expected_path="${expected_path%/}"
      actual_path="${actual_path%/}"
      ;;
  esac
  [ "$actual_path" = "$expected_path" ] ||
    die "Package '$pkg' moved in the source manifest ($expected_path -> $actual_path). Refusing to push."
}

push_check_source_conflicts() {
  local checkout="$1"
  local locked_sha="$2"
  local source_paths_name="$3"
  local -n source_paths_ref="$source_paths_name"
  local work_dir="$4"
  local i source_path base_file current_file

  for i in "${!source_paths_ref[@]}"; do
    source_path="${source_paths_ref[$i]}"
    push_validate_checkout_path "$checkout" "$source_path"

    base_file="$work_dir/base-$i"
    if ! git -C "$checkout" show "$locked_sha:$source_path" > "$base_file" 2>/dev/null; then
      die "Source file '$source_path' was not present at the locked SHA $locked_sha. Refusing to push."
    fi

    current_file="$work_dir/current-$i"
    if ! git -C "$checkout" show "HEAD:$source_path" > "$current_file" 2>/dev/null; then
      die "Source file is missing at current HEAD: $source_path"
    fi

    if ! cmp -s "$base_file" "$current_file"; then
      die "Source file '$source_path' changed since package '$locked_sha' was installed. Refusing to overwrite it."
    fi
  done
}

push_apply_files() {
  local checkout="$1"
  local pkg_type="$2"
  local work_dir="$3"
  local local_paths_name="$4"
  local source_paths_name="$5"
  local -n local_paths_ref="$local_paths_name"
  local -n source_paths_ref="$source_paths_name"
  local i local_path source_path local_file source_file staged_file

  for i in "${!local_paths_ref[@]}"; do
    local_path="${local_paths_ref[$i]}"
    source_path="${source_paths_ref[$i]}"
    local_file="$AGENTS_ORCHESTRA_DIR_ABS/$local_path"
    source_file="$checkout/$source_path"
    [ ! -L "$local_file" ] || die "Installed file is a symlink: $local_file"
    [ -f "$local_file" ] || die "Installed file is missing: $local_file"

    if [ "$pkg_type" = "agent" ]; then
      staged_file="$work_dir/agent-source.md"
      push_strip_agent_model "$local_file" "$staged_file"
      cp "$staged_file" "$source_file"
    else
      cp "$local_file" "$source_file"
    fi
  done
}

push_cmd() (
  local pkg=""
  local branch=""
  local dry_run=0
  local direct=0

  while [ $# -gt 0 ]; do
    case "$1" in
      --dry-run)
        dry_run=1
        shift
        ;;
      --direct)
        direct=1
        shift
        ;;
      --branch)
        [ $# -ge 2 ] || die "Usage: orchestra push <pkg> [--dry-run] [--branch NAME] [--direct]"
        branch="$2"
        shift 2
        ;;
      --branch=*)
        branch="${1#*=}"
        shift
        ;;
      --*)
        die "Unknown argument: $1"
        ;;
      *)
        [ -z "$pkg" ] || die "Usage: orchestra push <pkg> [--dry-run] [--branch NAME] [--direct]"
        pkg="$1"
        shift
        ;;
    esac
  done

  [ -n "$pkg" ] || die "Usage: orchestra push <pkg> [--dry-run] [--branch NAME] [--direct]"
  if [ "$direct" -eq 1 ] && [ -n "$branch" ]; then
    die "--branch cannot be used with --direct."
  fi
  ensure_orchestra_dir

  if ! lock_is_installed "$pkg"; then
    die "Package '$pkg' is not installed. Run 'orchestra list' to see installed packages."
  fi
  if ! lock_is_forked "$pkg"; then
    die "Package '$pkg' must be forked before pushing. Run 'orchestra fork $pkg' first."
  fi
  command -v git >/dev/null 2>&1 || die "Git is required for push. Install Git and try again."
  gh_check_auth
  ensure_pkg_dirs

  local provenance source source_repo pkg_type locked_sha source_path
  provenance="$(push_resolve_provenance "$pkg")"
  IFS=$'\t' read -r source source_repo pkg_type locked_sha source_path <<< "$provenance"

  local can_push
  can_push="$(gh_repo_push_permission "$source_repo" || true)"
  [ "$can_push" = "true" ] || die "GitHub account does not have push permission for '$source_repo'."

  local default_branch
  default_branch="$(gh_default_branch "$source_repo")"
  [ -n "$default_branch" ] || die "Could not determine the default branch for '$source_repo'."

  local work_dir checkout current_sha
  work_dir="$(mktemp -d)"
  trap 'rm -rf "$work_dir"' EXIT
  checkout="$work_dir/repository"

  if ! gh_clone_repo "$source_repo" "$checkout" >/dev/null 2>&1; then
    die "Could not clone '$source_repo'."
  fi
  git -C "$checkout" checkout -q "$default_branch" 2>/dev/null ||
    die "Could not check out '$default_branch' in '$source_repo'."

  current_sha="$(git -C "$checkout" rev-parse HEAD 2>/dev/null || true)"
  [ -n "$current_sha" ] || die "Could not determine the current HEAD for '$source_repo'."
  local api_sha
  api_sha="$(gh_head_sha "$source_repo" "$default_branch")"
  [ "$api_sha" = "$current_sha" ] ||
    die "Source '$source_repo' changed while it was being cloned. Retry the push."

  if ! git -C "$checkout" cat-file -e "$locked_sha^{commit}" 2>/dev/null; then
    git -C "$checkout" fetch --no-tags origin "$locked_sha" >/dev/null 2>&1 ||
      die "The locked SHA $locked_sha is not available in '$source_repo'."
  fi

  push_check_manifest_mapping "$checkout" "$pkg" "$pkg_type" "$source_path" "$work_dir"

  local local_paths=() source_paths=()
  push_collect_paths "$pkg" "$pkg_type" "$source_path" local_paths source_paths
  push_check_source_conflicts "$checkout" "$locked_sha" source_paths "$work_dir"
  push_apply_files "$checkout" "$pkg_type" "$work_dir" local_paths source_paths

  git -C "$checkout" add -- "${source_paths[@]}"
  if git -C "$checkout" diff --cached --quiet -- "${source_paths[@]}"; then
    die "No source changes found for '$pkg'."
  fi

  if [ "$dry_run" -eq 1 ]; then
    echo "Dry run for '$pkg' -> $source_repo"
    git -C "$checkout" diff --cached --stat -- "${source_paths[@]}"
    git -C "$checkout" diff --cached -- "${source_paths[@]}"
    exit 0
  fi

  if [ -z "$branch" ]; then
    local branch_pkg
    branch_pkg="${pkg//[^A-Za-z0-9._-]/-}"
    branch="orchestra/${branch_pkg}-$(date +%Y%m%d%H%M%S)-$$"
  fi
  git -C "$checkout" check-ref-format --branch "$branch" >/dev/null 2>&1 ||
    die "Invalid branch name: $branch"

  if [ "$direct" -eq 0 ]; then
    git -C "$checkout" checkout -q -b "$branch" "$default_branch" ||
      die "Could not create branch '$branch'."
  fi

  local commit_message="Update Orchestra package: $pkg"
  local git_name git_email
  git_name="$(git -C "$checkout" config user.name 2>/dev/null || true)"
  git_email="$(git -C "$checkout" config user.email 2>/dev/null || true)"
  git_name="${git_name:-Orchestra}"
  git_email="${git_email:-orchestra@localhost}"
  git -C "$checkout" -c user.name="$git_name" -c user.email="$git_email" \
    commit -m "$commit_message" >/dev/null || die "Could not create a commit for '$pkg'."

  local commit_sha
  commit_sha="$(git -C "$checkout" rev-parse HEAD)"

  if [ "$direct" -eq 1 ]; then
    local push_base_sha
    push_base_sha="$(gh_head_sha "$source_repo" "$default_branch")"
    [ "$push_base_sha" = "$current_sha" ] ||
      die "Source '$source_repo' changed before the direct push. Retry the push."
    if ! git -C "$checkout" push origin "HEAD:$default_branch" >/dev/null 2>&1; then
      die "Could not push '$pkg' to '$source_repo/$default_branch'. The remote may have changed; no local lockfile changes were made."
    fi
    lock_write_entry "$pkg" "$source" "$pkg_type" "$commit_sha" "$source_repo" "$source_path" "${local_paths[@]}"
    printf '%s\n' "$commit_sha" > "$(index_cache_dir_for "$source")/head.sha"
    log_info "Pushed '$pkg' directly to '$source_repo/$default_branch' @ ${commit_sha:0:12}."
  else
    if ! git -C "$checkout" push --set-upstream origin "$branch" >/dev/null 2>&1; then
      die "Could not push branch '$branch' to '$source_repo'."
    fi
    local pr_url pr_body
    pr_body="$(printf 'Update package '\''%s'\'' from Orchestra.\n\nBase SHA: %s.' "$pkg" "$locked_sha")"
    pr_url="$(gh_create_pull_request "$source_repo" "$branch" "$default_branch" "$commit_message" "$pr_body")" ||
      die "Branch '$branch' was pushed, but the pull request could not be created."
    echo "Pushed '$pkg' to '$source_repo/$branch'."
    echo "Pull request: $pr_url"
    log_info "The package remains forked until the pull request is merged."
  fi
)
