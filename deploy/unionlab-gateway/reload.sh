#!/bin/bash
# 重建容器以使 custom-ui 挂载、.env、compose 变更生效。
# 不要用 docker compose restart。
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.build.yml}"

"$SCRIPT_DIR/ensure-ui.sh"

echo "使用 $COMPOSE_FILE 重建容器（up -d，不是 restart）..."
docker compose -f "$COMPOSE_FILE" up -d "$@"

echo
echo "验证 UI 挂载："
docker inspect unionlab-gateway --format '{{range .Mounts}}{{println .Source "->" .Destination}}{{end}}'
echo
echo "日志中应出现: Using pre-restructured UI at /var/lib/litellm/ui"
docker compose -f "$COMPOSE_FILE" logs --tail=80 unionlab-gateway | grep -E "UI at |Using packaged UI|Using pre-restructured|Cannot restructure|invalid or incomplete" || true
