#!/usr/bin/env bash
# S18: real builds on a Sync. PHASE=prepare opens a pull request, waits for the two Pipelines builds, approves and moves main;
# the operator presses Sync; PHASE=watch polls the head, statuses and checks; PHASE=after approves again if needed and merges.
# The three phases share one evidence directory. PR is read from pr.txt unless set.
source "$(dirname "$0")/lib.sh"
PHASE="${PHASE:-prepare}"
TRY="${TRY:-t2}"
# One real status per run, and the rule needs two: once the real build is green, the harness posts the second (a reported deviation).
in_progress() { jq -r '[.body.values[]? | select(.state == "INPROGRESS")] | length' <<<"${A}" 2>/dev/null || echo 0; }
top_up() {
  if [[ "$(success_count)" == 1 && "$(in_progress)" == 0 ]]; then
    b "$DEFAULT_REVIEWER" "$1" status --pr "$2" --state SUCCESSFUL --key sim-build-b
  fi
}
success_count() { jq -r '[.body.values[]? | select(.state == "SUCCESSFUL")] | length' <<<"${A}" 2>/dev/null || echo 0; }
head_of() { jq -r '.body.source.commit.hash // "?"' <<<"${A}"; }
approved_count() { jq -r '[.body.participants[]? | select(.approved == true)] | length' <<<"${A}"; }
if [[ "$PHASE" == prepare ]]; then
  delivery_count >"${EVIDENCE_DIR}/start.txt"
  b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-$TRY-s18" --title "S18 real builds" --default-reviewers; PR=$(pr_id)
  echo "$PR" >"${EVIDENCE_DIR}/pr.txt"
  DEADLINE=$(( $(date +%s) + 600 )); POLL=0
  while :; do
    POLL=$(( POLL + 1 ))
    statuses_step "$AUTHOR" "02-statuses-p$POLL" "$PR"
    N=$(success_count)
    if [[ "$N" -ge 2 ]]; then break; fi
    top_up "02-top-up-p$POLL" "$PR"
    if [[ "$(date +%s)" -ge "$DEADLINE" ]]; then echo "shortfall: $N of 2 SUCCESSFUL after 10 minutes"; break; fi
    sleep 30
  done
  b "$DEFAULT_REVIEWER" 03-approve-default-reviewer approve --pr "$PR"
  b "$APPROVER" 04-approve-approver approve --pr "$PR"
  checks_step "$AUTHOR" 05-checks-approved "$PR"
  b "$AUTHOR" 06-read-before-sync read --pr "$PR"
  b "$AUTHOR" 07-open-mover open --branch "sim/$RUN_ID-$TRY-s18-mover" --title "S18 move main" --default-reviewers; MOVER=$(pr_id)
  b "$DEFAULT_REVIEWER" 08-status-a-default-reviewer status --pr "$MOVER" --state SUCCESSFUL --key sim-build-a
  b "$DEFAULT_REVIEWER" 09-status-b-default-reviewer status --pr "$MOVER" --state SUCCESSFUL --key sim-build-b
  b "$DEFAULT_REVIEWER" 10-approve-default-reviewer-mover approve --pr "$MOVER"
  b "$APPROVER" 11-approve-approver-mover approve --pr "$MOVER"
  b "$AUTHOR" 12-merge-mover merge --pr "$MOVER"
  checks_step "$AUTHOR" 13-checks-main-moved "$PR"
  echo "S18 pull request $PR"
  echo "press Sync on pull request $PR"
elif [[ "$PHASE" == watch ]]; then
  PR="${PR:-$(cat "${EVIDENCE_DIR}/pr.txt")}"
  b "$AUTHOR" w00-read-start read --pr "$PR"
  START_HEAD="$(head_of)"
  MOVED_AT=""
  POLL=0
  while [[ "$POLL" -lt 20 ]]; do
    POLL=$(( POLL + 1 )); P="$(printf '%02d' "$POLL")"
    b "$AUTHOR" "w$P-read" read --pr "$PR"
    HEAD="$(head_of)"
    echo "head $HEAD approved $(approved_count)"
    if [[ "$HEAD" != "$START_HEAD" && -z "$MOVED_AT" ]]; then MOVED_AT=$(date +%s); fi
    statuses_step "$AUTHOR" "w$P-statuses" "$PR"
    N=$(success_count)
    if [[ -n "$MOVED_AT" ]]; then top_up "w$P-top-up" "$PR"; fi
    checks_step "$AUTHOR" "w$P-checks" "$PR"
    if [[ -n "$MOVED_AT" && "$N" -ge 2 && $(( $(date +%s) - MOVED_AT )) -ge 90 ]]; then break; fi
    sleep 30
  done
else
  PR="${PR:-$(cat "${EVIDENCE_DIR}/pr.txt")}"
  b "$AUTHOR" 30-read-synced read --pr "$PR"
  if [[ "$(approved_count)" -lt 2 ]]; then
    b "$DEFAULT_REVIEWER" 31-approve-default-reviewer approve --pr "$PR"
    b "$APPROVER" 32-approve-approver approve --pr "$PR"
    checks_step "$AUTHOR" 33-checks-reapproved "$PR"
  fi
  b "$AUTHOR" 34-merge merge --pr "$PR"
  b "$AUTHOR" 35-read-merged read --pr "$PR"
  events_since "$(cat "${EVIDENCE_DIR}/start.txt")" "$PR"
fi
