#!/usr/bin/env bash
# S15: an edit/edit conflict on one existing line. A seed pull request puts the file on the default branch, then two pull requests edit it.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
F="sim-conflict/$RUN_ID-edit.txt"
b "$AUTHOR" 01-open-seed open --branch "sim/$RUN_ID-s15seed" --title "S15 seed" --path "$F" --content base --default-reviewers; SEED=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-successful status --pr "$SEED" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-successful status --pr "$SEED" --state SUCCESSFUL --key sim-build-b
b "$DEFAULT_REVIEWER" 04-approve-default-reviewer approve --pr "$SEED"
b "$APPROVER" 05-approve-approver approve --pr "$SEED"
checks_step "$AUTHOR" 05a-checks-seed "$SEED"
b "$AUTHOR" 06-merge-seed merge --pr "$SEED"
b "$AUTHOR" 07-open-first open --branch "sim/$RUN_ID-s15a" --title "S15 first" --path "$F" --content first --default-reviewers; P1=$(pr_id)
b "$AUTHOR" 08-open-second conflict --branch "sim/$RUN_ID-s15b" --title "S15 second" --path "$F" --content second --default-reviewers; P2=$(pr_id)
for W in first second; do
  if [[ "$W" == first ]]; then P="$P1"; else P="$P2"; fi
  b "$DEFAULT_REVIEWER" "09-status-a-successful-$W" status --pr "$P" --state SUCCESSFUL --key sim-build-a
  b "$DEFAULT_REVIEWER" "10-status-b-successful-$W" status --pr "$P" --state SUCCESSFUL --key sim-build-b
  b "$DEFAULT_REVIEWER" "11-approve-default-reviewer-$W" approve --pr "$P"
  b "$APPROVER" "12-approve-approver-$W" approve --pr "$P"
  checks_step "$AUTHOR" "12a-checks-approved-$W" "$P"
done
b "$AUTHOR" 13-merge-first merge --pr "$P1"
checks_step "$AUTHOR" 14-checks-second "$P2"
b "$AUTHOR" 15-merge-second merge --pr "$P2"
b "$AUTHOR" 16-read-second read --pr "$P2"
if [[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]]; then
  b "$AUTHOR" 17-close-second close --pr "$P2"
  checks_step "$AUTHOR" 18-checks-declined "$P2"
fi
events_since "$START" ""
