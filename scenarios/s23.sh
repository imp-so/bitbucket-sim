#!/usr/bin/env bash
# S23: a delivered event sent again. Cloud shows no manual resend, so the receiver answers 500 (FAIL_EVENT) and Bitbucket retries.
# PHASE=open opens a pull request and approves once; PHASE=compare (PR=<id>) compares that approval's deliveries by hash and declines.
source "$(dirname "$0")/lib.sh"
case "${PHASE:?open or compare}" in
  open)
    START=$(delivery_count)
    b "$AUTHOR" "01-open${SUFFIX:-}" open --branch "sim/$RUN_ID-s23${SUFFIX:-}" --title "S23 webhook retry" --default-reviewers; PR=$(pr_id)
    b "$APPROVER" "02-approve-approver${SUFFIX:-}" approve --pr "$PR"
    events_since "$START" "$PR"
    echo "S23 pull request $PR"
    ;;
  compare)
    : "${PR:?}"
    jq -s -c --arg pr "$PR" 'map(select(.eventKey == "pullrequest:approved" and (.pullRequest|tostring) == $pr))
      | {deliveries: length, attempts: map(.attempt), answered: map(.answered), signatures: map(.signature), at: map(.at[11:23]), eventKeys: (map(.eventKey) | unique),
         requestUuid: (if (map(.requestUuidHash) | unique | length) == 1 then "SAME" else "DIFFERENT" end),
         bodyBytes: (if (map(.bodySha256) | unique | length) == 1 then "SAME" else "DIFFERENT" end)}' "$DELIVERIES" | tee "$EVIDENCE_DIR/compare-$PR.json"
    b "$AUTHOR" "03-decline-$PR" close --pr "$PR"
    ;;
esac
