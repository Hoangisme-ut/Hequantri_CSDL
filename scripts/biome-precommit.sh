#!/usr/bin/env bash

set -euo pipefail

frontend_files=()
for file in "$@"; do
  case "$file" in
    frontend/*) frontend_files+=("${file#frontend/}") ;;
  esac
done

if ((${#frontend_files[@]} == 0)); then
  exit 0
fi

cd frontend

if command -v bunx >/dev/null 2>&1; then
  bunx_command=(bunx)
elif command -v bunx.exe >/dev/null 2>&1; then
  bunx_command=(bunx.exe)
elif command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
  bunx_windows_path="$(
    powershell.exe -NoProfile -Command \
      '(Get-Command bunx.exe -ErrorAction SilentlyContinue).Source' |
      tr -d '\r'
  )"

  if [[ -n "$bunx_windows_path" ]]; then
    bunx_path="$(wslpath -u "$bunx_windows_path")"

    if [[ -x "$bunx_path" ]]; then
      bunx_command=("$bunx_path")
    else
      echo "Error: Cannot execute Bunx at $bunx_path" >&2
      exit 127
    fi
  else
    echo "Error: Cannot locate bunx.exe on Windows." >&2
    exit 127
  fi
else
  echo "Error: bunx or bunx.exe is required to run Biome." >&2
  exit 127
fi

"${bunx_command[@]}" biome check --no-errors-on-unmatched --files-ignore-unknown=true "${frontend_files[@]}"
