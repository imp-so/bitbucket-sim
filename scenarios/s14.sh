#!/usr/bin/env bash
# S14: roles. One read of the effective default reviewers (the count only), then, from the S10 to S12 evidence, each participant's
# role and approved in the last read before the first merge, and whether any approval ran as the author.
source "$(dirname "$0")/lib.sh"
A="$(./"${AUTHOR}.sh" default-reviewers --name 01-default-reviewers)"
echo "01-default-reviewers $(jq -r '.body.values | length' <<<"$A")" | tee -a "${EVIDENCE_DIR}/steps.txt"
for S in s10 s11 s12; do
  D="evidence/${STAMP}/${S}"
  if ls "$D"/*.json >/dev/null 2>&1; then
    jq -rs --arg s "$S" '
      (map(select(.verb == "merge") | .label) | sort | first // "~") as $m
      | ([.[] | select(.verb == "read" and .label < $m)] | sort_by(.label) | last) as $r
      | "\($s): " + ($r | if . == null then "no read before merge" else ([.body.participants[]? | "\(.role) approved=\(.approved)"] | join("; ")) end)
        + " | approvals as author: \($r | if . == null then "?" else (.body.author.uuid as $a | [.body.participants[]? | select(.approved and .user.uuid == $a)] | length) end)"' "$D"/*.json
  else
    echo "$S: no evidence"
  fi
done
