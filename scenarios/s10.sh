#!/usr/bin/env bash
# S10: required builds. One FAILED and one SUCCESSFUL, both approvals, a refused merge, then the second build SUCCESSFUL and a merge.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s10" --title "S10 required builds" --default-reviewers; PR=$(pr_id)
checks_step "$AUTHOR" 02-checks-opened "$PR"
b "$DEFAULT_REVIEWER" 03-status-a-failed status --pr "$PR" --state FAILED --key sim-build-a
b "$DEFAULT_REVIEWER" 04-status-b-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 05-checks-builds-posted "$PR"
b "$DEFAULT_REVIEWER" 06-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 07-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 08-checks-approved "$PR"
b "$AUTHOR" 09-read-approved read --pr "$PR"
b "$AUTHOR" 10-merge-refused merge --pr "$PR"
checks_step "$AUTHOR" 11-checks-after-refusal "$PR"
b "$DEFAULT_REVIEWER" 12-status-a-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-a
checks_step "$AUTHOR" 13-checks-builds-ok "$PR"
b "$AUTHOR" 14-merge merge --pr "$PR"
events_since "$START" "$PR"
