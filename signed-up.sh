#!/usr/bin/env bash
# signed-up.sh <stamp>: starts the receiver and the tunnel with a new webhook secret held only in this process tree's environment:
# never a file, an argument or a log. Stopping the receiver loses the secret, so a later run starts here again.
set -euo pipefail
cd "$(dirname "$0")"
STAMP="${1:?usage: signed-up.sh <stamp>}"
if curl -s -o /dev/null -m 2 http://127.0.0.1:8787/; then echo "a receiver is already up; stop it first" >&2; exit 1; fi
WEBHOOK_SECRET="$(openssl rand -hex 32)"
export WEBHOOK_SECRET
nohup pnpm exec tsx receiver.ts "${STAMP}" >.local/receiver.log 2>&1 &
disown
for _ in $(seq 1 15); do
  curl -s -o /dev/null -m 2 http://127.0.0.1:8787/ && break
  sleep 1
done
curl -s -o /dev/null -m 2 http://127.0.0.1:8787/ || { echo "receiver did not start" >&2; exit 1; }
./tunnel.sh
