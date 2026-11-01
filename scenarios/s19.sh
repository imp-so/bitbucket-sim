#!/usr/bin/env bash
# S19: merge with an open change request. The default reviewer requests changes, the approver approves, the default reviewer tries to approve.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s19" --title "S19 open change request" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 05-request-changes-default-reviewer request-changes --pr "$PR"
checks_step "$AUTHOR" 06-checks-changes-requested "$PR"
b "$APPROVER" 07-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 08-checks-approver-approved "$PR"
b "$DEFAULT_REVIEWER" 09-approve-default-reviewer approve --pr "$PR"
b "$AUTHOR" 10-read-after-approve-attempt read --pr "$PR"
checks_step "$AUTHOR" 11-checks-after-approve-attempt "$PR"
b "$AUTHOR" 12-merge merge --pr "$PR"
b "$AUTHOR" 13-read-after-merge read --pr "$PR"
if [[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]]; then
  b "$AUTHOR" 14-decline close --pr "$PR"
fi
events_since "$START" "$PR"
