#!/usr/bin/env bash
# S9: a large pull request and its merge: a 202 or not. FILES sets the size.
source "$(dirname "$0")/lib.sh"
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s9" --title "S9 large" --files "${FILES:-1500}"; PR=$(pr_id)
b bot1 02-approve-bot1 approve --pr "$PR"
b bot2 03-approve-bot2 approve --pr "$PR"
SECONDS=0
b bot1 04-merge merge --pr "$PR"
echo "merge verb seconds: ${SECONDS}" | tee -a "$EVIDENCE_DIR/steps.txt"
b bot1 05-read-after read --pr "$PR"
