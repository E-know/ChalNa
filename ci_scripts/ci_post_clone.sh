#!/bin/sh
set -eu

cd "${CI_PRIMARY_REPOSITORY_PATH:?}"

if ! command -v mise >/dev/null 2>&1; then
    brew install mise
fi

tuist_tool=tuist@4.209.0
mise install "$tuist_tool"
mise exec "$tuist_tool" -- tuist install
mise exec "$tuist_tool" -- tuist generate --no-open
