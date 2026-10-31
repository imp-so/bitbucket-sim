#!/usr/bin/env bash
# S11: a fix commit after both approvals; do the approvals and builds reset, and which events arrive. Then builds and approvals again, and a merge.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s11" --title "S11 fix commit" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 05-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 06-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 07-checks-approved "$PR"
b "$AUTHOR" 08-push push --pr "$PR"
b "$AUTHOR" 09-read-pushed read --pr "$PR"
checks_step "$AUTHOR" 10-checks-pushed "$PR"
b "$AUTHOR" 11-statuses-pushed statuses --pr "$PR"
b "$DEFAULT_REVIEWER" 12-status-a-successful-new-head status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 13-status-b-successful-new-head status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 14-checks-new-builds "$PR"
b "$DEFAULT_REVIEWER" 15-approve-default-reviewer-again approve --pr "$PR"
b "$APPROVER" 16-approve-approver-again approve --pr "$PR"
checks_step "$AUTHOR" 17-checks-reapproved "$PR"
b "$AUTHOR" 17a-read-reapproved read --pr "$PR"
b "$AUTHOR" 18-merge merge --pr "$PR"
events_since "$START" "$PR"
