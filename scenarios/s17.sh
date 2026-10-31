#!/usr/bin/env bash
# S17: sync the default branch into an approved pull request. Do the approvals survive a sync when the pull request's
# own diff does not change? The API refuses a two-parent commit, so the operator presses Sync between two phases:
# PHASE=prepare, then PHASE=after with PR set. SUFFIX names a run, so it can repeat with "Keep approvals" ticked or not.
source "$(dirname "$0")/lib.sh"
SUFFIX="${SUFFIX:-keep-off}"
EVIDENCE_DIR="${EVIDENCE_DIR}-${SUFFIX}"; export EVIDENCE_DIR; mkdir -p "${EVIDENCE_DIR}"
PHASE="${PHASE:-prepare}"
ready() {
  b "$DEFAULT_REVIEWER" "$1-status-a" status --pr "$2" --state SUCCESSFUL --key sim-build-a
  b "$DEFAULT_REVIEWER" "$1-status-b" status --pr "$2" --state SUCCESSFUL --key sim-build-b
  b "$DEFAULT_REVIEWER" "$1-approve-default-reviewer" approve --pr "$2"
  b "$APPROVER" "$1-approve-approver" approve --pr "$2"
}
if [[ "$PHASE" == prepare ]]; then
  delivery_count >"${EVIDENCE_DIR}/start.txt"
  b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s17-$SUFFIX" --title "S17 sync $SUFFIX" --default-reviewers; PR=$(pr_id)
  ready 02 "$PR"
  checks_step "$AUTHOR" 03-checks-approved "$PR"
  b "$AUTHOR" 04-open-mover open --branch "sim/$RUN_ID-s17-$SUFFIX-mover" --title "S17 move main $SUFFIX" --default-reviewers; MOVER=$(pr_id)
  ready 05 "$MOVER"
  b "$AUTHOR" 06-merge-mover merge --pr "$MOVER"
  checks_step "$AUTHOR" 07-checks-main-moved "$PR"
  b "$AUTHOR" 08-read-before-sync read --pr "$PR"
  echo "press Sync on pull request $PR"
else
  : "${PR:?}"
  b "$AUTHOR" 09-read-synced read --pr "$PR"
  checks_step "$AUTHOR" 10-checks-synced "$PR"
  b "$AUTHOR" 11-statuses-synced statuses --pr "$PR"
  b "$AUTHOR" 12-close close --pr "$PR"
  events_since "$(cat "${EVIDENCE_DIR}/start.txt")" "$PR"
fi
