#!/bin/bash
# 确保 custom-ui 可被容器挂载。不构建 npm，只同步已有产物。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_OUT_DIR="$SCRIPT_DIR/../../litellm/proxy/_experimental/out"
DEPLOY_UI_DIR="$SCRIPT_DIR/custom-ui"

ui_is_valid() {
  local dir="$1"
  [[ -f "$dir/index.html" && -d "$dir/_next" ]]
}

mkdir -p "$DEPLOY_UI_DIR"

if ui_is_valid "$DEPLOY_UI_DIR"; then
  touch "$DEPLOY_UI_DIR/.litellm_ui_ready"
  echo "custom-ui 已就绪: $DEPLOY_UI_DIR"
  exit 0
fi

if ui_is_valid "$SOURCE_OUT_DIR"; then
  echo "custom-ui 不完整，正在从源码产物同步: $SOURCE_OUT_DIR"
  rm -rf "$DEPLOY_UI_DIR"/*
  cp -a "$SOURCE_OUT_DIR"/. "$DEPLOY_UI_DIR"/
  touch "$DEPLOY_UI_DIR/.litellm_ui_ready"
  echo "custom-ui 已同步: $DEPLOY_UI_DIR"
  exit 0
fi

echo "custom-ui 无效，且源码目录 litellm/proxy/_experimental/out 也没有可用产物。" >&2
echo "请先构建二开 UI：" >&2
echo "  cd $SCRIPT_DIR && ./build-ui.sh" >&2
exit 1
