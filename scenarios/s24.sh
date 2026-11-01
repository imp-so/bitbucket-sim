#!/usr/bin/env bash
# S24: the checks answer of a closed pull request. One merged pull request read twice, and DECLINED_PR as the pair.
source "$(dirname "$0")/lib.sh"
# One line per entry: its type, status, state and the sorted key paths. Values other than those stay out.
shape() {
  jq -c '.status as $http | .body as $b | {http: $http, entries: ($b.values | length), other: ($b | keys), values: [$b.values[] | {type, status, state, reason, kind: (.check.kind // .kind), keys: ([paths(scalars)] | map(map(tostring) | join(".")) | sort)}]}' <<<"$A" | tee -a "$EVIDENCE_DIR/shapes.txt"
}
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-s24" --title "S24 checks after merge" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-b
b "$DEFAULT_REVIEWER" 04-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 05-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 06-checks-open "$PR"
shape
b "$AUTHOR" 07-merge merge --pr "$PR"
checks_step "$AUTHOR" 08-checks-merged-at-once "$PR"
shape
sleep 10
checks_step "$AUTHOR" 09-checks-merged-after-10s "$PR"
shape
b "$AUTHOR" 10-read-merged read --pr "$PR"
checks_step "$AUTHOR" 11-checks-declined "${DECLINED_PR:?}"
shape
b "$AUTHOR" 12-read-declined read --pr "$DECLINED_PR"
events_since "$START" "$PR"
echo "S24 pull request $PR"
