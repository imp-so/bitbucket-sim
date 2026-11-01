#!/usr/bin/env bash
# S21: the "No changes are requested" box (ticked by the operator for this scenario only). Does approving clear a change request?
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s21" --title "S21 no changes requested" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 05-request-changes-default-reviewer request-changes --pr "$PR"
checks_step "$AUTHOR" 06-checks-changes-requested "$PR"
b "$APPROVER" 07-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 08-checks-approver-approved "$PR"
b "$AUTHOR" 09-merge-refused merge --pr "$PR"
b "$DEFAULT_REVIEWER" 10-approve-default-reviewer approve --pr "$PR"
b "$AUTHOR" 11-read-default-reviewer-approved read --pr "$PR"
checks_step "$AUTHOR" 12-checks-default-reviewer-approved "$PR"
b "$AUTHOR" 13-merge merge --pr "$PR"
b "$AUTHOR" 14-read-after-merge read --pr "$PR"
if [[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]]; then
  b "$AUTHOR" 15-decline close --pr "$PR"
fi
events_since "$START" "$PR"
