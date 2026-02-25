#!/bin/bash
# Plasma Quick Display Change – Standalone
# Startet die Anwendung als normales Fenster (ohne Plasma-Panel).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QML_FILE="$SCRIPT_DIR/contents/ui/main.qml"

QML_BIN=""
for cmd in qml6 qml; do
    if command -v "$cmd" &>/dev/null; then
        QML_BIN="$cmd"
        break
    fi
done

if [ -z "$QML_BIN" ]; then
    echo "Fehler: qml6 oder qml nicht gefunden."
    echo ""
    echo "Installation:"
    echo "  sudo apt install qt6-declarative-dev-tools   # Kubuntu/Ubuntu"
    echo "  sudo pacman -S qt6-declarative               # Arch"
    echo "  sudo dnf install qt6-qtdeclarative-devel     # Fedora"
    exit 1
fi

APP_ID="plasma-quick-display-change"
ICON_FILE="$SCRIPT_DIR/contents/icons/monitors.svg"
DESKTOP_FILE="$SCRIPT_DIR/$APP_ID.desktop"
LOCAL_DESKTOP="$HOME/.local/share/applications/$APP_ID.desktop"
LOCAL_ICON="$HOME/.local/share/icons/hicolor/scalable/apps/$APP_ID.svg"

if [ ! -f "$LOCAL_ICON" ] && [ -f "$ICON_FILE" ]; then
    mkdir -p "$(dirname "$LOCAL_ICON")"
    cp "$ICON_FILE" "$LOCAL_ICON"
fi
if [ ! -f "$LOCAL_DESKTOP" ] && [ -f "$DESKTOP_FILE" ]; then
    mkdir -p "$(dirname "$LOCAL_DESKTOP")"
    sed "s|Icon=ICON_PATH_PLACEHOLDER|Icon=$LOCAL_ICON|" "$DESKTOP_FILE" > "$LOCAL_DESKTOP"
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
fi

export QT_WAYLAND_APP_ID="$APP_ID"
if [ -f "$LOCAL_DESKTOP" ]; then
    export DESKTOP_FILE_HINT="$LOCAL_DESKTOP"
fi
exec "$QML_BIN" --qwindowicon "$ICON_FILE" "$QML_FILE" "$@"
