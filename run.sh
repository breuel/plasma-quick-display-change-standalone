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

exec "$QML_BIN" "$QML_FILE" "$@"
