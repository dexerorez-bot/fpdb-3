#!/usr/bin/env bash
#
# Startet fpdb-3 aus der von install-macos.sh angelegten .venv.
#
#   ./run-fpdb-macos.sh          # Hauptprogramm (GUI)
#   ./run-fpdb-macos.sh --hud    # nur den HUD-Prozess
#   ./run-fpdb-macos.sh --update # Repo aktualisieren und Abhängigkeiten nachziehen

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PY="$REPO_DIR/.venv/bin/python"

if [ ! -x "$VENV_PY" ]; then
    echo "Keine Installation gefunden. Bitte zuerst ./install-macos.sh ausführen." >&2
    exit 1
fi

cd "$REPO_DIR"

case "${1:-}" in
    --hud)
        shift
        exec "$VENV_PY" fpdb_3_legacy/HUD_main.pyw "$@" ;;
    --update)
        git pull --ff-only
        "$VENV_PY" -m pip install -e ".[macos]"
        echo "Aktualisiert." ;;
    *)
        exec "$VENV_PY" fpdb_3_legacy/fpdb.pyw "$@" ;;
esac
