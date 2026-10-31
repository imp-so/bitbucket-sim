#!/usr/bin/env bash
# S8: the happy path with the deliveries: open, status SUCCESSFUL, two approvals (one default reviewer), merge.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s8" --title "S8 happy path" --default-reviewers; PR=$(pr_id)
b bot1 02-status status --pr "$PR" --state SUCCESSFUL
b bot1 03-approve-bot1 approve --pr "$PR"
b bot2 04-approve-bot2 approve --pr "$PR"
b bot1 05-read read --pr "$PR"
b bot1 06-merge merge --pr "$PR"
b bot1 07-read-after read --pr "$PR"
events_since "$START" "$PR"
