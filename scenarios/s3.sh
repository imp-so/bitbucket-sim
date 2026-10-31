#!/usr/bin/env bash
# S3: approve, unapprove, read: the counts move.
source "$(dirname "$0")/lib.sh"
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s3" --title "S3 approval counts"; PR=$(pr_id)
b bot1 02-read-none read --pr "$PR"
b bot1 03-approve approve --pr "$PR"
b bot1 04-read-one read --pr "$PR"
b bot1 05-unapprove unapprove --pr "$PR"
b bot1 06-read-after read --pr "$PR"
b "$AUTHOR" 07-close close --pr "$PR"
