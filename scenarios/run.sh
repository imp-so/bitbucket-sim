#!/usr/bin/env bash
# run.sh <scenario>: runs scenarios/<scenario>.sh (arguments through the environment) with the receiver checked before and after,
# keeps the exit code and appends "<name> rc=<n> receiver=<up|down> <UTC time>" to evidence/$STAMP/rc.txt. RUN_LABEL names a phase.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
: "${STAMP:?}"
SCENARIO="${1:?usage: run.sh <scenario>}"
NAME="${RUN_LABEL:-${SCENARIO}}"
D="evidence/${STAMP}"
mkdir -p "${D}"
receiver() { if curl -s -o /dev/null -m 2 http://127.0.0.1:8787/; then echo up; else echo down; fi; }
if [[ "$(receiver)" != up ]]; then echo "receiver is down; not running ${NAME}" >&2; exit 5; fi
rc=0
bash "scenarios/${SCENARIO}.sh" >"${D}/${NAME}.out" 2>&1 || rc=$?
cat "${D}/${NAME}.out"
after="$(receiver)"
line="${NAME} rc=${rc} receiver=${after} $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "${line}" | tee -a "${D}/rc.txt"
if [[ "${after}" == down ]]; then exit 5; fi
exit "${rc}"
