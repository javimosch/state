#!/bin/sh
# build state — single static binary, no dependencies
set -e
cd "$(dirname "$0")"
machin encode src/state.src > state.mfl
machin build state.mfl -o state
echo "built: $(ls -la state | awk '{print $5, $9}')"
./state --help | head -3
