#!/usr/bin/env bash

set -euo pipefail

# Keep both entry points on the same isolated test lifecycle.
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$script_dir/test.sh" "$@"
