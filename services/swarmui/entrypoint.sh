#!/usr/bin/env bash

# Ensure correct local path.
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cd "$SCRIPT_DIR"

# Add dotnet non-admin-install to path
export PATH="$SCRIPT_DIR/.dotnet:~/.dotnet:$PATH"

# Default env configuration, gets overwritten by the C# code's settings handler
export ASPNETCORE_ENVIRONMENT="Production"
export ASPNETCORE_URLS="http://*:7801"
# Actual runner.
cd "$HOME"
dotnet ./bin/SwarmUI.dll "$@"

# Exit code 42 means restart, anything else = don't.
if [ $? == 42 ]; then
    . /entrypoint.sh "$@"
fi
