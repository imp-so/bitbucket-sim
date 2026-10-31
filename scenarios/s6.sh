#!/usr/bin/env bash
# S6: a build status FAILED then SUCCESSFUL on the head, the deliveries, a merge after SUCCESSFUL.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s6" --title "S6 build status"; PR=$(pr_id)
b bot1 02-status-failed status --pr "$PR" --state FAILED
b bot1 03-status-successful status --pr "$PR" --state SUCCESSFUL
b bot1 04-approve-bot1 approve --pr "$PR"
b bot2 05-approve-bot2 approve --pr "$PR"
b bot1 06-merge merge --pr "$PR"
events_since "$START" "$PR"
