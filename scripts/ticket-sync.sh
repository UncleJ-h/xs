#!/usr/bin/env bash
# ticket-sync.sh — xAI OAuth shared-ticket sync tool (co-ticket discipline)
#
# Background: a local hermes/xs + a remote 24/7 hermes instance can share ONE
# xAI OAuth ticket (same account, same client_id). xAI keeps only one live
# grant: a new device-auth login REVOKES the existing ticket, while refreshing
# with a stale (already-rotated) refresh token only fails locally
# (invalid_grant) and does NOT hurt the other side. Therefore:
#   - the always-on remote instance is the refresh master
#   - everyone else syncs FROM it instead of re-logging in
#
# Usage:
#   ticket-sync.sh pull   # remote -> local hermes + local grok CLI (default)
#                         #   run when local xs / grok CLI hits 401 / invalid_grant
#   ticket-sync.sh push   # local hermes -> remote (backs up + restarts container)
#                         #   run when the remote reports provider auth failure
#
# Iron rule: NEVER `grok login --device-auth` / `hermes auth add` while any
# copy is still alive — that revokes the shared grant for everyone. Re-login
# only when ALL copies are dead.
#
# Config (kept OUT of the repo): ~/.config/xs/ticket-sync.conf
#   VPS="user@host"                     # ssh target of the refresh master
#   VPS_AUTH="/path/to/hermes/auth.json" # hermes auth store on the remote
set -euo pipefail

CONF="${XS_TICKET_SYNC_CONF:-$HOME/.config/xs/ticket-sync.conf}"
if [[ ! -f "$CONF" ]]; then
  echo "error: config not found: $CONF" >&2
  echo "create it with:  VPS=\"user@host\"  and  VPS_AUTH=\"/path/to/auth.json\"" >&2
  exit 1
fi
# shellcheck disable=SC1090
source "$CONF"
: "${VPS:?VPS not set in $CONF}"
: "${VPS_AUTH:?VPS_AUTH not set in $CONF}"

LOCAL_HERMES_PY="${LOCAL_HERMES_PY:-$HOME/.hermes/hermes-agent/venv/bin/python3}"
DIRECTION="${1:-pull}"

case "$DIRECTION" in
pull)
  echo "[pull] remote(refresh master) -> local ..."
  FRESH_JSON=$(ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS" "sudo python3 -c \"
import json
d=json.load(open('$VPS_AUTH'))
t=d['providers']['xai-oauth']['tokens']
print(json.dumps({'access_token':t['access_token'],'refresh_token':t['refresh_token']}))
\"")
  FRESH_JSON="$FRESH_JSON" "$LOCAL_HERMES_PY" - <<'PYEOF'
import json, os, sys
HOME = os.path.expanduser('~')
sys.path.insert(0, os.path.join(HOME, '.hermes', 'hermes-agent'))
from hermes_cli.auth import _auth_store_lock, _load_auth_store, _save_auth_store
from datetime import datetime, timezone
fresh = json.loads(os.environ['FRESH_JSON'])
now = datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z')
with _auth_store_lock():
    store = _load_auth_store()
    e = store['credential_pool']['xai-oauth'][0]
    e['access_token'] = fresh['access_token']
    e['refresh_token'] = fresh['refresh_token']
    e['last_refresh'] = now
    for k in ('last_status','last_status_at','last_error_code','last_error_reason',
              'last_error_message','last_error_reset_at'):
        e[k] = None
    _save_auth_store(store)
print(f'[pull] done: local hermes pool[0] refreshed at {now}')

# also renew the local grok CLI copy (~/.grok/auth.json), if present
import base64
grok_path = os.path.join(HOME, '.grok', 'auth.json')
try:
    g = json.load(open(grok_path))
    gk = next(k for k in g if k.startswith('https://auth.x.ai::'))
    p = g[gk]
    was_str = isinstance(p, str)
    if was_str:
        p = json.loads(p)
    p['key'] = fresh['access_token']
    p['refresh_token'] = fresh['refresh_token']
    seg = fresh['access_token'].split('.')[1]
    seg += '=' * (-len(seg) % 4)
    exp = json.loads(base64.urlsafe_b64decode(seg)).get('exp')
    if exp:
        from datetime import datetime as _dt
        p['expires_at'] = _dt.fromtimestamp(exp, timezone.utc).isoformat().replace('+00:00', 'Z')
    g[gk] = json.dumps(p) if was_str else p
    with open(grok_path, 'w') as f:
        json.dump(g, f, indent=2)
    os.chmod(grok_path, 0o600)
    print(f"[pull] done: grok CLI auth.json refreshed (expires_at={p.get('expires_at')})")
except FileNotFoundError:
    print('[pull] skip: ~/.grok/auth.json not found (grok CLI not installed / never logged in)')
PYEOF
  ;;
push)
  echo "[push] local hermes -> remote(refresh master) ..."
  FRESH_JSON=$("$LOCAL_HERMES_PY" -c "
import json, os, sys
HOME = os.path.expanduser('~')
sys.path.insert(0, os.path.join(HOME, '.hermes', 'hermes-agent'))
from hermes_cli.auth import _load_auth_store
e = _load_auth_store()['credential_pool']['xai-oauth'][0]
print(json.dumps({'access_token':e['access_token'],'refresh_token':e['refresh_token']}))
")
  echo "$FRESH_JSON" | ssh -o ConnectTimeout=10 -o BatchMode=yes "$VPS" "sudo python3 -c \"
import json, sys
from datetime import datetime, timezone
fresh=json.load(sys.stdin)
path='$VPS_AUTH'
import shutil; shutil.copy2(path, path+'.bak-ticketsync')
d=json.load(open(path))
s=d['providers']['xai-oauth']
s['tokens']['access_token']=fresh['access_token']
s['tokens']['refresh_token']=fresh['refresh_token']
s['last_refresh']=datetime.now(timezone.utc).isoformat().replace('+00:00','Z')
s.pop('last_auth_error',None)
json.dump(d, open(path,'w'), indent=2)
print('[push] auth.json updated, restarting hermes container...')
\" && sudo docker restart hermes >/dev/null && echo '[push] done: remote hermes restarted'"
  ;;
*)
  echo "usage: $0 [pull|push]" >&2; exit 1 ;;
esac
