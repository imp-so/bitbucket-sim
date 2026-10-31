#!/usr/bin/env bash
# S7: a draft pull request: read and merge, with the approvals the rule asks for.
source "$(dirname "$0")/lib.sh"
b "$AUTHOR" 01-open-draft open --branch "sim/$RUN_ID-s7" --title "S7 draft" --draft; PR=$(pr_id)
b bot1 02-read read --pr "$PR"
b bot1 03-approve-bot1 approve --pr "$PR"
b bot2 04-approve-bot2 approve --pr "$PR"
b bot1 05-merge merge --pr "$PR"
b bot1 06-read-after read --pr "$PR"
[[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]] && b "$AUTHOR" 07-close close --pr "$PR"
