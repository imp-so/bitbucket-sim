#!/usr/bin/env bash
# S2: the default-reviewer rule. Opened with no named reviewer, to see whether the API adds the default reviewer;
# a second pull request names the effective default reviewers and runs the refusal and the merge.
source "$(dirname "$0")/lib.sh"
b "$AUTHOR" 01-open-unnamed open --branch "sim/$RUN_ID-s2a" --title "S2a default reviewer not named"; PR=$(pr_id)
b bot1 02-read-unnamed read --pr "$PR"
b "$AUTHOR" 03-close-unnamed close --pr "$PR"
b "$AUTHOR" 04-open open --branch "sim/$RUN_ID-s2b" --title "S2b default reviewer" --default-reviewers; PR=$(pr_id)
b bot2 05-approve-bot2 approve --pr "$PR"
b bot1 06-read read --pr "$PR"
b bot2 07-merge-refused merge --pr "$PR"
b bot1 08-approve-bot1 approve --pr "$PR"
b bot1 09-read read --pr "$PR"
b bot2 10-merge merge --pr "$PR"
b bot1 11-read-after read --pr "$PR"
