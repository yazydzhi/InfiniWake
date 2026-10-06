#!/bin/zsh
set -euo pipefail

# Собирает InfiniWake.dmg: иконка тома + перетаскивание в Applications.
# Требует: create-dmg (brew install create-dmg)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-1.1.1}"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-stage"
APP_SRC="$ROOT/.build-app/InfiniWake.app"
DMG_NAME="InfiniWake-${VERSION}"
DMG_PATH="$DIST/${DMG_NAME}.dmg"
VOLICON="$ROOT/Resources/AppIcon.icns"
BG_SRC="$ROOT/Resources/dmg-background.png"
BG_USE="$DIST/dmg-background-600x400.png"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "Нужен create-dmg: brew install create-dmg" >&2
    exit 1
fi

echo "→ Сборка .app…"
"$ROOT/scripts/build-app.sh"

if [[ ! -d "$APP_SRC" ]]; then
    echo "Нет $APP_SRC" >&2
    exit 1
fi

rm -rf "$STAGE" "$DMG_PATH"
mkdir -p "$STAGE" "$DIST"
ditto "$APP_SRC" "$STAGE/InfiniWake.app"

CREATE_ARGS=(
    --volname "InfiniWake"
    --window-pos 200 120
    --window-size 660 420
    --icon-size 100
    --icon "InfiniWake.app" 160 185
    --hide-extension "InfiniWake.app"
    --app-drop-link 500 185
    --no-internet-enable
)

if [[ -f "$VOLICON" ]]; then
    CREATE_ARGS+=(--volicon "$VOLICON")
fi

if [[ -f "$BG_SRC" ]]; then
    # create-dmg ожидает фон примерно под размер окна
    sips -z 400 660 "$BG_SRC" --out "$BG_USE" >/dev/null
    CREATE_ARGS+=(--background "$BG_USE")
fi

echo "→ Создание $DMG_PATH…"
# create-dmg пишет «skipping» если файл есть — мы уже удалили
create-dmg "${CREATE_ARGS[@]}" "$DMG_PATH" "$STAGE"

# Иногда create-dmg оставляет rw. / .temp — подчистить
rm -f "$DIST"/rw.*.InfiniWake*.dmg "$DIST"/.DS_Store 2>/dev/null || true
rm -rf "$STAGE"

echo "✓ DMG: $DMG_PATH"
ls -lh "$DMG_PATH"
