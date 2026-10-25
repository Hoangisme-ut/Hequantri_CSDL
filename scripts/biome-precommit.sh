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
bunx biome check --no-errors-on-unmatched --files-ignore-unknown=true "${frontend_files[@]}"
