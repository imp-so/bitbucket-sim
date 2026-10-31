# Sourced by each scenario. Needs STAMP; AUTHOR (default bot3, the operator's account) opens the pull requests so bot1 and bot2 are
# never reviewing their own work. `b <bot> <step> <verb> [flags]` runs one verb and leaves its masked answer in $A.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
: "${STAMP:?}"
AUTHOR="${AUTHOR:-bot3}"
SCENARIO="$(basename "$0" .sh)"
RUN_ID="$(tr "[:upper:]" "[:lower:]" <<<"${STAMP}")"
export EVIDENCE_DIR="${ROOT}/evidence/${STAMP}/${SCENARIO}"
DELIVERIES="${ROOT}/evidence/${STAMP}/deliveries.jsonl"
mkdir -p "${EVIDENCE_DIR}"
SETTLE_SECONDS="${SETTLE_SECONDS:-12}"

b() {
  local who="$1" step="$2" verb="$3"; shift 3
  local rc=0
  A="$(./"${who}.sh" "${verb}" --name "${step}" "$@")" || rc=$?
  printf '%s %s %s\n' "${step}" "$(jq -r '.status' <<<"${A}")" "$(jq -c '{state: .body.state, type: .body.type, error: .body.error.message}' <<<"${A}")" | tee -a "${EVIDENCE_DIR}/steps.txt"
  [[ "${rc}" == 0 ]] || { echo "${step}: stopped, exit ${rc}" >&2; return "${rc}"; }
}
pr_id() { jq -r '.body.id' <<<"${A}"; }
delivery_count() { [[ -f "${DELIVERIES}" ]] && wc -l <"${DELIVERIES}" | tr -d ' ' || echo 0; }
# events_since <line count> <pull request id or empty>: the event keys after that line, in order, into events.txt.
events_since() {
  sleep "${SETTLE_SECONDS}"
  tail -n "+$(( $1 + 1 ))" "${DELIVERIES}" 2>/dev/null | jq -r --arg pr "${2:-}" 'select($pr == "" or .pullRequest == null or (.pullRequest|tostring) == $pr) | "\(.at) \(.eventKey) pr=\(.pullRequest)"' | tee "${EVIDENCE_DIR}/events.txt"
}
