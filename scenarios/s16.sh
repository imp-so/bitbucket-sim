#!/usr/bin/env bash
# S16: both builds SUCCESSFUL and both approvals, then sim-build-b FAILED on the head; is the merge still allowed.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s16" --title "S16 failed build at merge" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 05-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 06-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 07-checks-approved "$PR"
b "$DEFAULT_REVIEWER" 08-status-b-failed status --pr "$PR" --state FAILED --key sim-build-b
checks_step "$AUTHOR" 09-checks-b-failed "$PR"
b "$AUTHOR" 10-statuses statuses --pr "$PR"
b "$AUTHOR" 11-merge merge --pr "$PR"
b "$AUTHOR" 12-read-after read --pr "$PR"
if [[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]]; then
  b "$AUTHOR" 13-close close --pr "$PR"
fi
events_since "$START" "$PR"
