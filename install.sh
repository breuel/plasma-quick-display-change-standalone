#!/bin/bash
# Plasma Quick Display Change – Installer
# Installiert die Anwendung nach ~/.local/ (kein sudo nötig).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

APP_NAME="plasma-quick-display-change"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

echo "=== $APP_NAME – Installation ==="
echo ""

# Abhängigkeiten prüfen
MISSING=""
for cmd in qml6 kscreen-doctor; do
    if ! command -v "$cmd" &>/dev/null; then
        MISSING="$MISSING $cmd"
    fi
done

if [ -n "$MISSING" ]; then
    echo "Warnung: Folgende Abhängigkeiten fehlen:$MISSING"
    echo ""
    echo "Installation der Abhängigkeiten (Paketnamen je nach Distro unterschiedlich):"
    echo "  Kubuntu/Ubuntu:  sudo apt install qt6-declarative-dev-tools libkscreen2-tools"
    echo "  Debian:          sudo apt install qml-qt6 libkscreen-bin"
    echo "  (Falls nicht gefunden: apt search kscreen bzw. apt search qml)"
    echo ""
    read -rp "Trotzdem fortfahren? [j/N] " answer
    if [[ ! "$answer" =~ ^[jJyY]$ ]]; then
        echo "Abgebrochen."
        exit 1
    fi
fi

# Anwendungsdateien kopieren
echo "Installiere nach $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cp -r "$SCRIPT_DIR/contents" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/run.sh" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/run.sh"

# Startskript in ~/.local/bin
echo "Erstelle Startskript in $BIN_DIR ..."
mkdir -p "$BIN_DIR"
cat > "$BIN_DIR/$APP_NAME" << 'LAUNCHER'
#!/bin/bash
exec "$HOME/.local/share/plasma-quick-display-change/run.sh" "$@"
LAUNCHER
chmod +x "$BIN_DIR/$APP_NAME"

# Icon installieren
echo "Installiere Icon ..."
mkdir -p "$ICON_DIR"
cp "$SCRIPT_DIR/contents/icons/monitors.svg" "$ICON_DIR/$APP_NAME.svg"

# .desktop-Datei installieren (Icon- und Exec-Pfad einsetzen)
echo "Installiere Desktop-Eintrag ..."
mkdir -p "$DESKTOP_DIR"
sed -e "s|Icon=ICON_PATH_PLACEHOLDER|Icon=$ICON_DIR/$APP_NAME.svg|" \
    -e "s|Exec=EXEC_PATH_PLACEHOLDER|Exec=$BIN_DIR/$APP_NAME|" \
    "$SCRIPT_DIR/$APP_NAME.desktop" > "$DESKTOP_DIR/$APP_NAME.desktop"

# Desktop-Datenbank aktualisieren
if command -v update-desktop-database &>/dev/null; then
    update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

echo ""
echo "Installation abgeschlossen!"
echo ""
echo "Starten mit:"
echo "  $APP_NAME                        (Terminal)"
echo "  Oder über das Anwendungsmenü     (\"Plasma Quick Display Change\")"
echo ""

# Prüfen ob ~/.local/bin im PATH ist
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Hinweis: $BIN_DIR ist nicht in deinem \$PATH."
    echo "Füge folgende Zeile zu ~/.bashrc hinzu:"
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
fi
