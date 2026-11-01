#!/usr/bin/env bash
# S22: in-progress builds. Pull request one: sim-build-a INPROGRESS, then SUCCESSFUL. Pull request two: sim-build-a STOPPED. How is each counted?
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s22" --title "S22 in-progress build" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-default-reviewer-inprogress status --pr "$PR" --state INPROGRESS --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 04-checks-inprogress "$PR"
statuses_step "$AUTHOR" 05-statuses-inprogress "$PR"
b "$DEFAULT_REVIEWER" 06-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 07-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 08-checks-approved "$PR"
b "$AUTHOR" 09-merge-refused merge --pr "$PR"
b "$DEFAULT_REVIEWER" 10-status-a-default-reviewer-successful status --pr "$PR" --state SUCCESSFUL --key sim-build-a
checks_step "$AUTHOR" 11-checks-builds-ok "$PR"
b "$AUTHOR" 12-read-before-merge read --pr "$PR"
b "$AUTHOR" 13-merge merge --pr "$PR"
b "$AUTHOR" 14-read-after-merge read --pr "$PR"
if [[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]]; then
  b "$AUTHOR" 15-decline close --pr "$PR"
fi
b "$AUTHOR" 20-open-stopped open --branch "sim/$RUN_ID-s22-stopped" --title "S22 stopped build" --default-reviewers; PR2=$(pr_id)
b "$DEFAULT_REVIEWER" 21-status-a-default-reviewer-stopped status --pr "$PR2" --state STOPPED --key sim-build-a
b "$DEFAULT_REVIEWER" 22-status-b-default-reviewer status --pr "$PR2" --state SUCCESSFUL --key sim-build-b
checks_step "$AUTHOR" 23-checks-stopped "$PR2"
statuses_step "$AUTHOR" 24-statuses-stopped "$PR2"
b "$AUTHOR" 25-decline close --pr "$PR2"
events_since "$START" ""
