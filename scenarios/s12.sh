#!/usr/bin/env bash
# S12: the default reviewer requests changes (a comment if the API has no such call), the author pushes a fix, builds and approvals again, a merge.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s12" --title "S12 reviewer cycle" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 05-request-changes-default-reviewer request-changes --pr "$PR"
if [[ "$(jq -r '.status' <<<"$A")" == 404 || "$(jq -r '.status' <<<"$A")" == 405 ]]; then
  b "$DEFAULT_REVIEWER" 06-comment-default-reviewer comment --pr "$PR" --text "changes requested (the API has no request-changes)"
fi
checks_step "$AUTHOR" 07-checks-changes-requested "$PR"
b "$AUTHOR" 08-push push --pr "$PR"
checks_step "$AUTHOR" 09-checks-pushed "$PR"
b "$DEFAULT_REVIEWER" 10-status-a-successful-new-head status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 11-status-b-successful-new-head status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 12-checks-new-builds "$PR"
b "$DEFAULT_REVIEWER" 13-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 14-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 15-checks-approved "$PR"
b "$AUTHOR" 16-read-approved read --pr "$PR"
b "$AUTHOR" 17-merge merge --pr "$PR"
events_since "$START" "$PR"
