#!/bin/sh
# build (if needed) and install state to ~/.local/bin
set -e
cd "$(dirname "$0")"
if [ ! -x ./state ] || [ src/state.src -nt ./state ]; then
	./build.sh
fi
mkdir -p "$HOME/.local/bin"
cp ./state "$HOME/.local/bin/state"
chmod +x "$HOME/.local/bin/state"
echo "installed: $HOME/.local/bin/state"
echo "make sure \$HOME/.local/bin is on your PATH"
