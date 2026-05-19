#!/usr/bin/env bash
# xs - one-line installer
#
# Usage:
#   bash install.sh
#   # or remote:
#   curl -sSL https://raw.githubusercontent.com/UncleJ-h/xs/main/install.sh | bash

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC} $1"; }
err() { echo -e "${RED}✗${NC} $1" >&2; }
warn() { echo -e "${YELLOW}⚠${NC} $1"; }

echo ""
echo "🔍 xs installer — Grok X Search CLI"
echo ""

HERMES_PY=""
for candidate in \
    "${HERMES_DIR:-}/venv/bin/python" \
    "$HOME/.hermes/hermes-agent/venv/bin/python"; do
    if [ -x "$candidate" ]; then
        HERMES_PY="$candidate"
        break
    fi
done

if [ -z "$HERMES_PY" ]; then
    err "Hermes Agent not installed."
    echo "  Install first: brew install hermes-agent"
    echo "  Or: pip install hermes-agent"
    exit 1
fi
ok "Hermes Agent found: $HERMES_PY"

HERMES_BIN="$(dirname "$HERMES_PY")/hermes"
if ! "$HERMES_BIN" auth status xai-oauth 2>&1 | grep -q "logged in"; then
    warn "xAI OAuth not configured."
    echo "  Run: hermes auth add xai-oauth"
    echo "  Then re-run this installer."
    exit 1
fi
ok "xAI OAuth configured"

INSTALL_DIR="$HOME/.local/bin"
SHARE_DIR="$HOME/.local/share/xs"
mkdir -p "$INSTALL_DIR" "$SHARE_DIR"

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SOURCE_DIR/xs_cli.py" "$SHARE_DIR/xs_cli.py"
cp "$SOURCE_DIR/xs" "$INSTALL_DIR/xs"
chmod +x "$INSTALL_DIR/xs"
ok "Installed: $INSTALL_DIR/xs"
ok "Installed: $SHARE_DIR/xs_cli.py"

if ! echo ":$PATH:" | grep -q ":$INSTALL_DIR:"; then
    warn "$INSTALL_DIR is not in your PATH"
    echo "  Add to ~/.zshrc or ~/.bashrc:"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

echo ""
echo "🧪 Running smoke test (calls Grok x_search, ~30s)..."
echo ""
if "$INSTALL_DIR/xs" --answer-only "What is the Hermes Agent project?" 2>&1 | head -3; then
    echo ""
    ok "Smoke test PASSED"
else
    err "Smoke test FAILED"
    exit 1
fi

echo ""
echo "🎉 Done! Try:"
echo "    xs \"your query here\""
echo "    xs --handle elonmusk \"latest tweets\""
echo "    xs --help"
echo ""
echo "Examples: $SOURCE_DIR/examples/"
echo "Repo:     https://github.com/UncleJ-h/xs"
