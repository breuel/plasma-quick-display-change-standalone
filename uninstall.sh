#!/bin/bash
# Plasma Quick Display Change – Uninstaller
# Entfernt die Anwendung aus ~/.local/.

set -euo pipefail

APP_NAME="plasma-quick-display-change"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_FILE="$HOME/.local/bin/$APP_NAME"
DESKTOP_FILE="$HOME/.local/share/applications/$APP_NAME.desktop"
ICON_FILE="$HOME/.local/share/icons/hicolor/scalable/apps/$APP_NAME.svg"

echo "=== $APP_NAME – Deinstallation ==="
echo ""

FOUND=false
for f in "$INSTALL_DIR" "$BIN_FILE" "$DESKTOP_FILE" "$ICON_FILE"; do
    if [ -e "$f" ]; then
        FOUND=true
        break
    fi
done

if [ "$FOUND" = false ]; then
    echo "Nichts zu entfernen – Anwendung ist nicht installiert."
    exit 0
fi

echo "Folgende Dateien werden entfernt:"
[ -d "$INSTALL_DIR" ]  && echo "  $INSTALL_DIR/"
[ -f "$BIN_FILE" ]     && echo "  $BIN_FILE"
[ -f "$DESKTOP_FILE" ] && echo "  $DESKTOP_FILE"
[ -f "$ICON_FILE" ]    && echo "  $ICON_FILE"
echo ""

read -rp "Wirklich deinstallieren? [j/N] " answer
if [[ ! "$answer" =~ ^[jJyY]$ ]]; then
    echo "Abgebrochen."
    exit 0
fi

[ -d "$INSTALL_DIR" ]  && rm -rf "$INSTALL_DIR"  && echo "Entfernt: $INSTALL_DIR/"
[ -f "$BIN_FILE" ]     && rm -f "$BIN_FILE"      && echo "Entfernt: $BIN_FILE"
[ -f "$DESKTOP_FILE" ] && rm -f "$DESKTOP_FILE"   && echo "Entfernt: $DESKTOP_FILE"
[ -f "$ICON_FILE" ]    && rm -f "$ICON_FILE"      && echo "Entfernt: $ICON_FILE"

if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

echo ""
echo "Deinstallation abgeschlossen."
