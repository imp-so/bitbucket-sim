#!/usr/bin/env bash
# Operator only: stores one bot's email and API token in SSM. The token comes from a hidden prompt and reaches the
# AWS CLI through a private temp file, never an argument. Usage: ./store-bot.sh <bot> <email>
set -euo pipefail
BOT="${1:?bot}"; EMAIL="${2:?email}"
[[ "${BOT}" =~ ^bot[0-9]$ ]] || { echo "bot must look like bot1" >&2; exit 2; }
CONFIG="$(dirname "$0")/.local/fixtures.json"
PREFIX="$(jq -r .parameterPrefix "${CONFIG}")/${BOT}"
AWS=(aws-vault exec "$(jq -r .vaultProfile "${CONFIG}")" --no-session -- aws ssm put-parameter --region "$(jq -r .region "${CONFIG}")" --overwrite --output text --query Version)

umask 077
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT
printf 'Paste the API token for %s (hidden), then Enter: ' "${BOT}"
IFS= read -rs TOKEN
echo
[[ -n "${TOKEN}" ]] || { echo "empty token, nothing stored" >&2; exit 1; }
printf '%s' "${TOKEN}" >"${TMP}"
unset TOKEN

"${AWS[@]}" --name "${PREFIX}/token" --type SecureString --value "file://${TMP}" >/dev/null
"${AWS[@]}" --name "${PREFIX}/email" --type String --value "${EMAIL}" >/dev/null
echo "stored ${BOT}"
