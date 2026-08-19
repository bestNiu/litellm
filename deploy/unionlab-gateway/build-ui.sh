#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UI_DIR="$(cd "$SCRIPT_DIR/../../ui/litellm-dashboard" && pwd)"
SOURCE_OUT_DIR="$SCRIPT_DIR/../../litellm/proxy/_experimental/out"
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

if [[ ! -f ./out/index.html || ! -d ./out/_next ]]; then
  echo "UI 构建产物不完整：缺少 out/index.html 或 out/_next" >&2
  exit 1
fi

mkdir -p "$SOURCE_OUT_DIR" "$DEPLOY_UI_DIR"
rm -rf "${SOURCE_OUT_DIR:?}/"* "${DEPLOY_UI_DIR:?}/"*
cp -a ./out/. "$SOURCE_OUT_DIR"/
cp -a ./out/. "$DEPLOY_UI_DIR"/
rm -rf ./out

touch "$SOURCE_OUT_DIR/.litellm_ui_ready" "$DEPLOY_UI_DIR/.litellm_ui_ready"

echo "UI build deployed to:"
echo "  $DEPLOY_UI_DIR"
echo "  $SOURCE_OUT_DIR"
echo
echo "接下来请重建容器以重新挂载 custom-ui（不要用 restart）："
echo "  $SCRIPT_DIR/reload.sh"
