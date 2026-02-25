# Plasma Quick Display Change – Standalone

Eigenständige Desktop-Anwendung zum schnellen Wechseln und Verwalten von Monitor-Konfigurationen unter KDE Plasma 6. Läuft als normales Fenster ohne Plasma-Panel.

![License](https://img.shields.io/badge/license-GPL--3.0--or--later-blue)

| Hauptansicht | Einstellungen |
|:---:|:---:|
| ![Hauptansicht](Screenshot_01.png) | ![Einstellungen](Screenshot_02.png) |

## Features

- **Gespeicherte Profile** – Aktuelle Monitor-Konfiguration als benanntes Profil speichern und per Klick wiederherstellen
- **Quick Layouts** – Nebeneinander, Erweitern links/rechts, Gestapelt, Spiegeln, Nur Hauptbildschirm
- **Monitor-Steuerung** – Monitore aktivieren/deaktivieren, Primärbildschirm festlegen
- **Layout-Editor** – Drag & Drop-Vorschau der Monitor-Positionen mit Snapping
- **Monitor-Identifikation** – Overlay auf jedem Monitor mit Name und Auflösung
- **16 Sprachen** – Deutsch, Englisch, Ungarisch, Französisch, Spanisch, Italienisch, Portugiesisch (BR), Russisch, Polnisch, Niederländisch, Türkisch, Japanisch, Koreanisch, Chinesisch (vereinfacht/traditionell)
- **Einstellungen werden gespeichert** – Profile und Sprache bleiben über Neustarts erhalten

## Voraussetzungen

- **KDE Plasma 6** (Frameworks & Qt 6)
- **kscreen-doctor** – Teil von `libkscreen` / `plasma-workspace`
- **qml6** – QML-Runtime aus Qt 6

### Installation der Abhängigkeiten

```bash
# Kubuntu / Ubuntu
sudo apt install qt6-declarative-dev-tools libkscreen2-tools

# Arch Linux
sudo pacman -S qt6-declarative libkscreen

# Fedora
sudo dnf install qt6-qtdeclarative-devel kscreen
```

## Installation

Die Anwendung lässt sich als Benutzer-Programm installieren (kein `sudo` nötig):

```bash
./install.sh
```

Das Installationsskript:
- Kopiert die Anwendungsdateien nach `~/.local/share/plasma-quick-display-change/`
- Erstellt ein Startskript in `~/.local/bin/plasma-quick-display-change`
- Installiert das Anwendungs-Icon nach `~/.local/share/icons/hicolor/scalable/apps/`
- Erstellt einen `.desktop`-Eintrag in `~/.local/share/applications/` (Anwendungsmenü)
- Prüft vorher, ob die Abhängigkeiten (`qml6`, `kscreen-doctor`) vorhanden sind

Nach der Installation ist die Anwendung verfügbar über:
- **Terminal:** `plasma-quick-display-change`
- **Anwendungsmenü:** Suche nach „Plasma Quick Display Change"

> **Hinweis:** Falls `~/.local/bin` nicht im `$PATH` ist, diesen Eintrag in `~/.bashrc` ergänzen:
> ```bash
> export PATH="$HOME/.local/bin:$PATH"
> ```

### Deinstallation

```bash
./uninstall.sh
```

Entfernt alle installierten Dateien aus `~/.local/` nach Bestätigung. Die Einstellungsdatei (`~/.config/Unknown Organization/qml6.conf`) wird nicht entfernt.

## Starten (ohne Installation)

Die Anwendung kann auch direkt ohne Installation gestartet werden:

```bash
./run.sh
```

Das Skript findet automatisch `qml6` oder `qml` und öffnet die Anwendung als eigenständiges Fenster. Beim ersten Start werden Icon und `.desktop`-Datei automatisch nach `~/.local/` kopiert, damit das Fenster in der Taskleiste korrekt dargestellt wird.

## Nutzung

1. **Monitore anzeigen** – Beim Start werden alle angeschlossenen Monitore erkannt und angezeigt.
2. **Quick Layouts** – Vorgefertigte Anordnungen (Nebeneinander, Erweitern, Spiegeln etc.) mit einem Klick anwenden.
3. **Profil speichern** – „Aktuelles als Profil speichern" klicken, Namen vergeben. Das Profil speichert die vollständige kscreen-doctor-JSON-Konfiguration.
4. **Profil laden** – Gespeichertes Profil per „Anwenden" wiederherstellen.
5. **Layout-Editor** – Monitore per Drag & Drop in der Vorschau anordnen, dann „Anwenden" klicken.
6. **Einstellungen** – Über das Globus-Icon: Sprache, Badge-Anzeige, Löschbestätigung konfigurieren.

## Projektstruktur

```
├── run.sh                                  # Startskript
├── install.sh                              # Installer (nach ~/.local/)
├── uninstall.sh                            # Deinstallation
├── plasma-quick-display-change.desktop     # Desktop-Eintrag (Vorlage)
├── contents/
│   ├── ui/
│   │   ├── main.qml                       # Hauptfenster (ApplicationWindow)
│   │   ├── FullRepresentation.qml          # Haupt-UI (Profile, Layouts, Monitore)
│   │   ├── CommandRunner.qml               # Shell-Befehlsausführung via Plasma DataSource
│   │   ├── Translations.qml               # Übersetzungen (16 Sprachen)
│   │   ├── MonitorDelegate.qml            # Einzelner Monitor-Eintrag in der Liste
│   │   ├── LayoutEditor.qml               # Drag & Drop Layout-Vorschau
│   │   └── IdentifyWindow.qml             # Monitor-Identifikations-Overlay
│   └── icons/
│       ├── monitors.svg                    # Anwendungs-Icon
│       └── monitor-single.svg             # Einzelner Monitor (Listen-Icon)
├── .gitignore
└── README.md
```

## Technik

- **Erkennung:** `kscreen-doctor -o` liefert die aktuelle Monitor-Konfiguration (Text-Output wird geparst).
- **Speichern:** `kscreen-doctor -j` liefert die vollständige Konfiguration als JSON – wird als Profil abgelegt.
- **Laden:** Aus dem gespeicherten JSON wird ein `kscreen-doctor`-Befehl gebaut (z. B. `output.DP-2.enable output.DP-2.position.0,0 output.DP-2.mode.1`).
- **Befehlsausführung:** Über die `Plasma5Support.DataSource` mit Engine `executable` (funktioniert auch außerhalb des Plasma-Panels).
- **Persistenz:** `QtCore.Settings` speichert Profile und Einstellungen in `~/.config/Unknown Organization/qml6.conf` (Standalone-Modus).
- **Fenster-Icon:** Wird über `--qwindowicon` gesetzt. Die Zuordnung zum Taskleisten-Eintrag erfolgt über `StartupWMClass=org.qt-project.qml` in der `.desktop`-Datei sowie `QT_WAYLAND_APP_ID` und `DESKTOP_FILE_HINT` auf Wayland.

## Herkunft

Basiert auf [izll/plasma-quick-display-change](https://github.com/izll/plasma-quick-display-change) (Quick Display Change für Plasma 6, Autor: izll). Erweitert um gespeicherte Display-Profile und Standalone-Modus.

## Lizenz

GPL-3.0-or-later
