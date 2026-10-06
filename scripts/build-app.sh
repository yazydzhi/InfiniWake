#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/.build-app"
APP="$BUILD/InfiniWake.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"
HELPER_SRC="$ROOT/helper/infiniwake-pmset.c"
HELPER_OUT="$BUILD/infiniwake-pmset"
VERSION="1.1.1"
BUILD_NUMBER="3"

echo "→ Сборка InfiniWake ${VERSION} (universal: arm64 + x86_64)…"
rm -rf "$BUILD"
mkdir -p "$BIN_DIR" "$RES_DIR"

# Privileged helper — universal
echo "  helper…"
clang -O2 -arch arm64 -arch x86_64 -o "$HELPER_OUT" "$HELPER_SRC"

# Swift: две архитектуры + lipo.
# SPM кладёт обе сборки в один путь — копируем arm64 до сборки x86_64.
cd "$ROOT"
ARM_SLICE="$BUILD/InfiniWake-arm64"
X86_SLICE="$BUILD/InfiniWake-x86_64"

echo "  swift arm64…"
swift build -c release --product InfiniWake --arch arm64
cp "$(swift build -c release --arch arm64 --show-bin-path)/InfiniWake" "$ARM_SLICE"
lipo -info "$ARM_SLICE"

echo "  swift x86_64…"
swift build -c release --product InfiniWake --arch x86_64
cp "$(swift build -c release --arch x86_64 --show-bin-path)/InfiniWake" "$X86_SLICE"
lipo -info "$X86_SLICE"

UNIVERSAL_BIN="$BUILD/InfiniWake-universal"
lipo -create "$ARM_SLICE" "$X86_SLICE" -output "$UNIVERSAL_BIN"
echo "  universal:"
lipo -info "$UNIVERSAL_BIN"
lipo -info "$HELPER_OUT"

cp "$UNIVERSAL_BIN" "$BIN_DIR/InfiniWake"
cp "$HELPER_OUT" "$BIN_DIR/infiniwake-pmset"
chmod +x "$BIN_DIR/InfiniWake" "$BIN_DIR/infiniwake-pmset"

# Иконка приложения
if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
    cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
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
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2026 Владимир Языджи</string>
    <key>CFBundleGetInfoString</key>
    <string>InfiniWake ${VERSION} — Владимир Языджи</string>
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

echo "✓ Готово: $INSTALL_APP (universal)"
echo "  (копия сборки: $APP)"
file "$BIN_DIR/InfiniWake" "$BIN_DIR/infiniwake-pmset"
echo "  Запуск: open \"$INSTALL_APP\""
echo "  Для закрытой крышки: $ROOT/scripts/install-helper.sh"
