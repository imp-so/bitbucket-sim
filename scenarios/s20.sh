#!/usr/bin/env bash
# S20: a push after a change request. Does the push clear changes_requested? Then builds, approvals and a merge on the new head.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s20" --title "S20 push after change request" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 05-request-changes-default-reviewer request-changes --pr "$PR"
b "$AUTHOR" 06-read-changes-requested read --pr "$PR"
checks_step "$AUTHOR" 07-checks-changes-requested "$PR"
b "$AUTHOR" 08-push push --pr "$PR"
b "$AUTHOR" 09-read-pushed read --pr "$PR"
checks_step "$AUTHOR" 10-checks-pushed "$PR"
b "$DEFAULT_REVIEWER" 11-status-a-default-reviewer-new-head status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 12-status-b-default-reviewer-new-head status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 13-checks-new-builds "$PR"
b "$DEFAULT_REVIEWER" 14-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 15-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 16-checks-approved "$PR"
b "$AUTHOR" 17-read-approved read --pr "$PR"
b "$AUTHOR" 18-merge merge --pr "$PR"
b "$AUTHOR" 19-read-after-merge read --pr "$PR"
if [[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]]; then
  b "$AUTHOR" 20-decline close --pr "$PR"
fi
events_since "$START" "$PR"
