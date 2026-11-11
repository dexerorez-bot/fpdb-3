# fpdb-3 auf macOS installieren

Zwei Wege – je nachdem, ob du nur spielen oder auch am Code arbeiten willst.

| Weg | Für wen | Aufwand |
| --- | --- | --- |
| **A. Fertige App** | nur benutzen, Apple Silicon (M1–M4) | 2 Minuten |
| **B. Aus dem Quellcode** (dieser Fork) | eigene Änderungen, Intel-Mac, neueste Entwicklungsversion | ca. 10 Minuten |

---

## A. Fertige App (Apple Silicon)

1. Unter [Releases](https://github.com/jejellyroll-fr/fpdb-3/releases/latest) die Datei
   `fpdb-pyoxidizer-macos-arm64` herunterladen.
2. Im Terminal entpacken (nicht per Finder – sonst setzt macOS die Quarantäne-Markierung):
   ```bash
   cd ~/Downloads
   unzip fpdb-pyoxidizer-macos-arm64.zip
   mkdir -p fpdb-pyoxidizer-macos-arm64
   tar -xzf fpdb-pyoxidizer-macos-arm64.tar.gz -C fpdb-pyoxidizer-macos-arm64
   ```
3. `fpdb.app` nach `/Applications` verschieben und starten.
4. Falls macOS meldet, die App sei beschädigt oder nicht verifiziert (nur bei nicht notarisierten Builds):
   ```bash
   xattr -dr com.apple.quarantine /Applications/fpdb.app
   ```

Hintergrund: [docs/macos-gatekeeper.md](docs/macos-gatekeeper.md).

---

## B. Aus dem Quellcode

### Voraussetzungen

- macOS 12 (Monterey) oder neuer, Apple Silicon oder Intel
- Internetverbindung, Admin-Passwort (für Homebrew beim ersten Mal)

Alles andere – Xcode Command Line Tools, Homebrew, Python 3.13, CMake, gettext – prüft und
installiert das Skript selbst.

### Installation

```bash
git clone https://github.com/<DEIN-GITHUB-NAME>/fpdb-3.git
cd fpdb-3
git switch macos-install      # nur nötig, solange der Branch nicht gemerged ist
./install-macos.sh
```

Optionen:

| Option | Wirkung |
| --- | --- |
| `--dev` | zusätzlich Test- und Lint-Werkzeuge (pytest, ruff, mypy) |
| `--postgres` / `--mysql` | Treiber-Extras für diese Datenbanken (SQLite ist Standard) |
| `--no-launcher` | keinen `FPDB.command`-Starter auf dem Schreibtisch anlegen |

Fehlen die Xcode Command Line Tools, öffnet das Skript den Installationsdialog und bricht ab –
nach deren Installation einfach erneut `./install-macos.sh` ausführen. Das Skript lässt sich
beliebig oft wiederholen.

### Starten

```bash
./run-fpdb-macos.sh           # Hauptprogramm
./run-fpdb-macos.sh --hud     # nur der HUD
```

oder per Doppelklick auf **FPDB.command** auf dem Schreibtisch.

### Aktualisieren

```bash
./run-fpdb-macos.sh --update
```

Holt die neuesten Änderungen aus deinem Fork (`git pull`) und zieht die Abhängigkeiten nach.
Um Änderungen des Originalprojekts zu übernehmen, den Fork vorher auf GitHub mit
**Sync fork** abgleichen oder lokal:

```bash
git remote add upstream https://github.com/jejellyroll-fr/fpdb-3.git   # einmalig
git fetch upstream
git merge upstream/development
```

---

## macOS-Rechte für den HUD

Damit der HUD Pokertische erkennen und darüber liegen kann, braucht macOS zwei Freigaben unter
**Systemeinstellungen → Datenschutz & Sicherheit**:

- **Bildschirm- & Systemaudioaufnahme** – nur um Fenstertitel und -positionen der Tische zu lesen;
  fpdb nimmt weder Bild noch Ton auf.
- **Bedienungshilfen** – um den HUD an den Tisch zu heften (und bei Winamax die Sitzplätze zu lesen).

Wichtig bei der Quellcode-Installation: macOS vergibt die Rechte an das Programm, **aus dem** fpdb
gestartet wird – also *Terminal* (bzw. iTerm o. Ä.), nicht an „fpdb“. Bei der fertigen App gehen die
Rechte an `fpdb.app`.

Im HUD gibt es außerdem den Knopf **macOS Permissions…**, der fehlende Rechte gezielt anfragt.
Den aktuellen Stand prüfen:

```bash
.venv/bin/python -m tools.grant_macos_permissions --check-status
```

Beim ersten Auto-Import fragt macOS eventuell noch, ob fpdb auf Daten anderer Apps zugreifen darf
(die Hand-History-Ordner der Pokerräume) – das bestätigen.

---

## Probleme

| Symptom | Lösung |
| --- | --- |
| `xcrun: error: invalid active developer path` | `xcode-select --install`, danach Skript erneut starten |
| Fehler beim Bauen von `pypoker-eval` | `brew install cmake` prüfen; `xcode-select -p` muss einen Pfad liefern. fpdb läuft auch ohne – nur Equity/All-in-EV fehlen dann |
| `Library not loaded: …libshiboken6…` | betrifft die fertige App → Quarantäne entfernen (siehe Abschnitt A) |
| HUD erscheint nicht über dem Tisch | Rechte oben prüfen, Terminal danach komplett beenden und neu öffnen |
| `brew: command not found` nach der Installation | `eval "$(/opt/homebrew/bin/brew shellenv)"` (Intel: `/usr/local/bin/brew`) |
| Installation komplett zurücksetzen | `rm -rf .venv` und `./install-macos.sh` erneut ausführen |

Deine Datenbank und Einstellungen liegen außerhalb des Repos in `~/.fpdb` und bleiben beim
Neuinstallieren erhalten.
