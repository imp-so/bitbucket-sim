#!/usr/bin/env bash
# S4: merge with one approval: the refusal.
source "$(dirname "$0")/lib.sh"
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s4" --title "S4 one approval"; PR=$(pr_id)
b bot1 02-approve approve --pr "$PR"
b bot1 03-merge merge --pr "$PR"
b bot1 04-read read --pr "$PR"
[[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]] && b "$AUTHOR" 05-close close --pr "$PR"
