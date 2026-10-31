#!/usr/bin/env bash
# One shot: starts a quick tunnel to the receiver, reads its URL from the private log and points the harness's hook
# on the fixtures repository at it, creating the hook or re-pointing it by its description. Prints no URL.
set -euo pipefail
cd "$(dirname "$0")"
LOG=.local/tunnel.log
if [[ -f .local/tunnel.pid ]] && kill -0 "$(cat .local/tunnel.pid)" 2>/dev/null; then
  kill "$(cat .local/tunnel.pid)"
fi
: >"${LOG}"
nohup cloudflared tunnel --no-autoupdate --url http://localhost:8787 >"${LOG}" 2>&1 &
echo $! >.local/tunnel.pid
disown
for _ in $(seq 1 30); do
  grep -Eq 'https://[a-z0-9-]+-[a-z0-9-]+\.trycloudflare\.com' "${LOG}" && break
  sleep 1
done
grep -Eq 'https://[a-z0-9-]+-[a-z0-9-]+\.trycloudflare\.com' "${LOG}" || { echo "no tunnel URL after 30 s" >&2; exit 1; }
./bot3.sh webhook --url-file "${LOG}" | jq -c '{status, request: .request.method, active: .body.active, events: (.body.events | length)}'
