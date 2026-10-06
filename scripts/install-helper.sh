#!/bin/zsh
set -euo pipefail

# Ставит узкий helper + sudoers, чтобы InfiniWake мог держать Mac awake с закрытой крышкой.
# Требует пароль администратора один раз.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HELPER_SRC="$ROOT/helper/infiniwake-pmset.c"
HELPER_DST="/Library/PrivilegedHelperTools/infiniwake-pmset"
SUDOERS="/etc/sudoers.d/infiniwake-pmset"
USER_NAME="$(id -un)"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "→ Компиляция helper…"
clang -O2 -o "$TMP/infiniwake-pmset" "$HELPER_SRC"

echo "→ Установка в $HELPER_DST (нужен sudo)…"
sudo mkdir -p /Library/PrivilegedHelperTools
sudo cp "$TMP/infiniwake-pmset" "$HELPER_DST"
sudo chown root:wheel "$HELPER_DST"
sudo chmod 755 "$HELPER_DST"

echo "→ Sudoers: только on|off|display-sleep без пароля…"
cat > "$TMP/sudoers" <<EOF
# InfiniWake — только три команды pmset-helper
$USER_NAME ALL=(root) NOPASSWD: $HELPER_DST on, $HELPER_DST off, $HELPER_DST display-sleep
EOF
sudo cp "$TMP/sudoers" "$SUDOERS"
sudo chmod 440 "$SUDOERS"
sudo chown root:wheel "$SUDOERS"
sudo visudo -cf "$SUDOERS"

echo "✓ Helper установлен. Проверка:"
sudo -n "$HELPER_DST" off && echo "  sudo -n infiniwake-pmset off — OK"
