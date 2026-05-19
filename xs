#!/usr/bin/env bash
# xs - Grok X Search CLI (wrapper)
#
# Locates the Hermes Agent venv Python and runs xs_cli.py
# Repo: https://github.com/UncleJ-h/xs

set -e

HERMES_PY=""
for candidate in \
    "${HERMES_DIR:-}/venv/bin/python" \
    "$HOME/.hermes/hermes-agent/venv/bin/python" \
    "$HOME/Library/Application Support/hermes/hermes-agent/venv/bin/python"; do
    if [ -x "$candidate" ]; then
        HERMES_PY="$candidate"
        break
    fi
done

if [ -z "$HERMES_PY" ]; then
    echo "[xs] ERROR: Hermes Agent venv not found." >&2
    echo "  Install: brew install hermes-agent" >&2
    echo "  Or set HERMES_DIR env var to your install path." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XS_CLI=""
for candidate in \
    "$SCRIPT_DIR/xs_cli.py" \
    "$HOME/.local/share/xs/xs_cli.py" \
    "/usr/local/share/xs/xs_cli.py"; do
    if [ -f "$candidate" ]; then
        XS_CLI="$candidate"
        break
    fi
done

if [ -z "$XS_CLI" ]; then
    echo "[xs] ERROR: xs_cli.py not found." >&2
    exit 1
fi

exec "$HERMES_PY" "$XS_CLI" "$@"
