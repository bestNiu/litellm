#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$(cd "$SCRIPT_DIR/../../ui/litellm-dashboard" && pwd)"
SOURCE_OUT_DIR="$(cd "$UI_DIR/../../litellm/proxy/_experimental/out" && pwd)"
DEPLOY_UI_DIR="$SCRIPT_DIR/custom-ui"

export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
if [ -s "$NVM_DIR/nvm.sh" ]; then
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"
else
  echo "nvm not found. Install Node.js 20 first, e.g.:"
  echo "  curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash"
  exit 1
fi

nvm use v20

cd "$UI_DIR"
npm install
npm run build

mkdir -p "$SOURCE_OUT_DIR" "$DEPLOY_UI_DIR"
rm -rf "$SOURCE_OUT_DIR"/* "$DEPLOY_UI_DIR"/*
cp -r ./out/* "$SOURCE_OUT_DIR"/
cp -r ./out/* "$DEPLOY_UI_DIR"/
rm -rf ./out

echo "UI build deployed to:"
echo "  $DEPLOY_UI_DIR"
echo "  $SOURCE_OUT_DIR"
