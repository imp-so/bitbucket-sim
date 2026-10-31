#!/usr/bin/env bash
# S1: open without reviewers; bot1 and bot2 approve; read the roles.
source "$(dirname "$0")/lib.sh"
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s1" --title "S1 no reviewers"; PR=$(pr_id)
b bot1 02-approve-bot1 approve --pr "$PR"
b bot2 03-approve-bot2 approve --pr "$PR"
b bot1 04-read read --pr "$PR"
b "$AUTHOR" 05-close close --pr "$PR"
