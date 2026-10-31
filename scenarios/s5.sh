#!/usr/bin/env bash
# S5: two pull requests change the same line of one new file; the first merges, the second answers the conflict.
source "$(dirname "$0")/lib.sh"
F="sim-conflict/$RUN_ID.txt"
b "$AUTHOR" 01-open-first open --branch "sim/$RUN_ID-s5a" --title "S5 first" --path "$F" --content first; P1=$(pr_id)
b "$AUTHOR" 02-conflict conflict --branch "sim/$RUN_ID-s5b" --title "S5 second" --path "$F" --content second; P2=$(pr_id)
for P in "$P1" "$P2"; do
  b bot1 "03-approve-bot1-$P" approve --pr "$P"
  b bot2 "04-approve-bot2-$P" approve --pr "$P"
done
b bot1 05-merge-first merge --pr "$P1"
b bot1 06-read-second read --pr "$P2"
b bot1 07-merge-second merge --pr "$P2"
b bot1 08-read-after read --pr "$P2"
[[ "$(jq -r '.body.state' <<<"$A")" == OPEN ]] && b "$AUTHOR" 09-close close --pr "$P2"
