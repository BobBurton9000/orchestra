#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
ORCHESTRA_SCRIPT="$SCRIPT_DIR/orchestra.sh"

if [[ ! -x "$ORCHESTRA_SCRIPT" ]]; then
  printf 'Orchestra entry point not found or not executable: %s\n' "$ORCHESTRA_SCRIPT" >&2
  exit 1
fi

if [[ -z "${HOME:-}" ]]; then
  echo 'HOME is not set; cannot determine where to install the launcher.' >&2
  exit 1
fi

BIN_DIR="$HOME/.local/bin"
LAUNCHER="$BIN_DIR/orchestra"
MARKER='# Generated and managed by Orchestra install.sh.'

mkdir -p "$BIN_DIR"

if [[ -e "$LAUNCHER" || -L "$LAUNCHER" ]] && ! grep -Fqx "$MARKER" "$LAUNCHER" 2>/dev/null; then
  printf 'Refusing to overwrite existing file: %s\n' "$LAUNCHER" >&2
  printf 'Move it aside or remove it, then run ./install.sh again.\n' >&2
  exit 1
fi

tmp_file="$(mktemp "$BIN_DIR/.orchestra.XXXXXX")"
trap 'rm -f -- "$tmp_file"' EXIT

printf '#!/usr/bin/env bash\n%s\nexec %q "$@"\n' "$MARKER" "$ORCHESTRA_SCRIPT" > "$tmp_file"
chmod 755 "$tmp_file"
mv -f -- "$tmp_file" "$LAUNCHER"
trap - EXIT

printf 'Installed Orchestra launcher: %s\n' "$LAUNCHER"
if [[ ":${PATH:-}:" == *":$BIN_DIR:"* ]]; then
  echo 'The launcher directory is on PATH.'
else
  printf 'Note: %s is not on PATH. Add it to the environment used to launch your shell and Pi:\n' "$BIN_DIR"
  printf '  export PATH="$HOME/.local/bin:$PATH"\n'
fi
