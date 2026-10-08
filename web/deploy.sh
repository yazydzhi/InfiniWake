#!/bin/zsh
set -euo pipefail

# Деплой статического сайта InfiniWake на ponravilos.ru
ROOT="$(cd "$(dirname "$0")" && pwd)"
HOST="${DEPLOY_HOST:-root@ponravilos.ru}"
REMOTE_DIR="${DEPLOY_REMOTE_DIR:-/opt/www/html/infiniwake}"

echo "→ rsync $ROOT/ → $HOST:$REMOTE_DIR/"
rsync -avz --delete \
  --exclude '.DS_Store' \
  --exclude 'deploy.sh' \
  "$ROOT/" "$HOST:$REMOTE_DIR/"

echo "✓ Файлы на сервере"
echo "  https://ponravilos.ru/infiniwake/"
echo "  (поддомен infiniwake.ponravilos.ru — после A-записи в Hostkey DNS)"
