#!/usr/bin/env bash
#
# fpdb-3 – Installation aus dem Quellcode für macOS
#
# Was das Skript macht:
#   1. prüft macOS-Version und Architektur
#   2. stellt Xcode Command Line Tools, Homebrew, Python 3.13 und CMake sicher
#   3. legt eine virtuelle Umgebung (.venv) im Repo an
#   4. installiert fpdb-3 inkl. nativer Equity-Engine (pypoker-eval)
#   5. kompiliert die Übersetzungen und prüft die Installation
#   6. legt einen Starter "FPDB.command" auf dem Schreibtisch an (optional)
#
# Aufruf (aus dem Repo-Verzeichnis):
#   ./install-macos.sh            # Standardinstallation
#   ./install-macos.sh --dev      # zusätzlich Test-/Entwickler-Extras
#   ./install-macos.sh --postgres # zusätzlich PostgreSQL-Extra
#   ./install-macos.sh --no-launcher
#
# Das Skript kann gefahrlos mehrfach ausgeführt werden.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$REPO_DIR/.venv"
PYTHON_FORMULA="python@3.13"
EXTRAS="macos"
CREATE_LAUNCHER=1

for arg in "$@"; do
    case "$arg" in
        --dev)         EXTRAS="$EXTRAS,test" ;;
        --postgres)    EXTRAS="$EXTRAS,postgresql" ;;
        --mysql)       EXTRAS="$EXTRAS,mysql" ;;
        --no-launcher) CREATE_LAUNCHER=0 ;;
        -h|--help)
            sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *) echo "Unbekannte Option: $arg (siehe --help)" >&2; exit 2 ;;
    esac
done

bold()  { printf '\033[1m%s\033[0m\n' "$*"; }
ok()    { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn()  { printf '  \033[33m!\033[0m %s\n' "$*"; }
fail()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------------------
bold "1/6  System prüfen"
[ "$(uname -s)" = "Darwin" ] || fail "Dieses Skript ist nur für macOS gedacht."

MACOS_VERSION="$(sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
ARCH="$(uname -m)"
ok "macOS $MACOS_VERSION ($ARCH)"
if [ "$MACOS_MAJOR" -lt 12 ]; then
    warn "macOS < 12 ist ungetestet – PySide6 6.8 setzt macOS 12 oder neuer voraus."
fi
if [ "$ARCH" = "x86_64" ] && [ "$(sysctl -in sysctl.proc_translated 2>/dev/null || echo 0)" = "1" ]; then
    warn "Terminal läuft unter Rosetta. Für Apple Silicon besser ein natives Terminal verwenden."
fi

# ---------------------------------------------------------------------------
bold "2/6  Werkzeuge sicherstellen"

if ! xcode-select -p >/dev/null 2>&1; then
    warn "Xcode Command Line Tools fehlen – Installationsdialog wird geöffnet."
    xcode-select --install || true
    fail "Bitte die Command Line Tools fertig installieren und das Skript danach erneut starten."
fi
ok "Xcode Command Line Tools: $(xcode-select -p)"

if ! command -v brew >/dev/null 2>&1; then
    # Homebrew kann bereits installiert, aber nicht im PATH sein
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then eval "$("$candidate" shellenv)"; break; fi
    done
fi
if ! command -v brew >/dev/null 2>&1; then
    warn "Homebrew nicht gefunden – wird installiert (fragt nach deinem Passwort)."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then eval "$("$candidate" shellenv)"; break; fi
    done
    command -v brew >/dev/null 2>&1 || fail "Homebrew-Installation fehlgeschlagen."
fi
ok "Homebrew: $(brew --version | head -1)"

for formula in "$PYTHON_FORMULA" cmake gettext; do
    if brew list --formula "$formula" >/dev/null 2>&1; then
        ok "$formula vorhanden"
    else
        echo "  → brew install $formula"
        brew install "$formula"
    fi
done

PYTHON_BIN="$(brew --prefix "$PYTHON_FORMULA")/bin/python3.13"
[ -x "$PYTHON_BIN" ] || fail "Python 3.13 nicht gefunden unter $PYTHON_BIN"
ok "Python: $("$PYTHON_BIN" --version)"

# ---------------------------------------------------------------------------
bold "3/6  Virtuelle Umgebung"
if [ -x "$VENV_DIR/bin/python" ] && "$VENV_DIR/bin/python" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
    ok "vorhandene .venv wird weiterverwendet"
else
    rm -rf "$VENV_DIR"
    "$PYTHON_BIN" -m venv "$VENV_DIR"
    ok ".venv angelegt"
fi
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"
python -m pip install --quiet --upgrade pip setuptools wheel
ok "pip $(pip --version | awk '{print $2}')"

# ---------------------------------------------------------------------------
bold "4/6  fpdb-3 installieren (Extras: $EXTRAS)"
echo "  Das dauert beim ersten Mal einige Minuten – pypoker-eval wird aus dem Quellcode gebaut."
export CMAKE_BUILD_PARALLEL_LEVEL="${CMAKE_BUILD_PARALLEL_LEVEL:-$(sysctl -n hw.ncpu)}"
pip install -e "${REPO_DIR}[${EXTRAS}]"
ok "Pakete installiert"

# ---------------------------------------------------------------------------
bold "5/6  Übersetzungen & Prüfung"
python "$REPO_DIR/tools/compile_translations.py" >/dev/null && ok "Übersetzungen kompiliert"

python - <<'PY'
import importlib, sys
failed = []
for mod in ("PySide6.QtWidgets", "numpy", "pandas", "zmq", "pyqtgraph", "objc", "Quartz", "AppKit"):
    try:
        importlib.import_module(mod)
    except Exception as exc:  # noqa: BLE001
        failed.append(f"{mod}: {exc}")
try:
    import pokereval  # noqa: F401
    print("  \033[32m✓\033[0m Equity-Engine (pypoker-eval) geladen")
except Exception as exc:  # noqa: BLE001
    print(f"  \033[33m!\033[0m Equity-Engine nicht ladbar ({exc}) – fpdb startet trotzdem, nur Equity/EV fehlen")
if failed:
    print("  \033[31m✗\033[0m Fehlende Module:\n    " + "\n    ".join(failed))
    sys.exit(1)
print("  \033[32m✓\033[0m Kernmodule importierbar")
PY

# ---------------------------------------------------------------------------
bold "6/6  Starter"
chmod +x "$REPO_DIR/run-fpdb-macos.sh"
if [ "$CREATE_LAUNCHER" -eq 1 ]; then
    LAUNCHER="$HOME/Desktop/FPDB.command"
    cat > "$LAUNCHER" <<EOF
#!/bin/bash
exec "$REPO_DIR/run-fpdb-macos.sh" "\$@"
EOF
    chmod +x "$LAUNCHER"
    ok "Starter angelegt: $LAUNCHER (Doppelklick startet fpdb)"
else
    ok "kein Schreibtisch-Starter (--no-launcher)"
fi

echo
bold "Fertig."
cat <<EOF
  Starten:      $REPO_DIR/run-fpdb-macos.sh
                (oder Doppelklick auf FPDB.command auf dem Schreibtisch)
  Nur der HUD:  $REPO_DIR/run-fpdb-macos.sh --hud

  Für den HUD braucht macOS die Rechte "Bildschirmaufnahme" und "Bedienungshilfen"
  für das Programm, aus dem fpdb gestartet wird (z. B. Terminal).
  Details: INSTALL_MACOS.md
EOF
