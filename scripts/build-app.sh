#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build-app"
APP="$BUILD/InfiniWake.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
HELPER_SRC="$ROOT/helper/infiniwake-pmset.c"
HELPER_OUT="$BUILD/infiniwake-pmset"

echo "→ Сборка InfiniWake…"
rm -rf "$BUILD"
mkdir -p "$BIN_DIR" "$RES_DIR"

# Privileged helper (локальная копия; системная ставится install-helper.sh)
clang -O2 -o "$HELPER_OUT" "$HELPER_SRC"

# Swift package → release binary
cd "$ROOT"
swift build -c release --product InfiniWake

SWIFT_BIN="$(swift build -c release --show-bin-path)/InfiniWake"
cp "$SWIFT_BIN" "$BIN_DIR/InfiniWake"
cp "$HELPER_OUT" "$BIN_DIR/infiniwake-pmset"
chmod +x "$BIN_DIR/InfiniWake" "$BIN_DIR/infiniwake-pmset"

# Иконка приложения
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>InfiniWake</string>
    <key>CFBundleIdentifier</key>
    <string>com.azg.InfiniWake</string>
    <key>CFBundleName</key>
    <string>InfiniWake</string>
    <key>CFBundleDisplayName</key>
    <string>InfiniWake</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1.0</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Владимир Языджи</string>
    <key>CFBundleGetInfoString</key>
    <string>InfiniWake 1.1.0 — Владимир Языджи</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>InfiniWake убирает настоящий Caps Lock из ввода, пока лампочка используется как индикатор keep-awake. Нажатия не сохраняются и никуда не отправляются.</string>
</dict>
</plist>
PLIST

# ad-hoc sign for local run
codesign --force --deep --sign - "$APP" 2>/dev/null || true

# Стабильный путь: иначе каждый запуск из .build-app ломает Accessibility (новый CDHash/путь)
INSTALL_APP="/Applications/InfiniWake.app"
echo "→ Установка в $INSTALL_APP…"
rm -rf "$INSTALL_APP"
ditto "$APP" "$INSTALL_APP"
codesign --force --deep --sign - "$INSTALL_APP" 2>/dev/null || true
xattr -dr com.apple.quarantine "$INSTALL_APP" 2>/dev/null || true

echo "✓ Готово: $INSTALL_APP"
echo "  (копия сборки: $APP)"
echo "  Запуск: open \"$INSTALL_APP\""
echo "  Для закрытой крышки: $ROOT/scripts/install-helper.sh"
