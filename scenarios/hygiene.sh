#!/usr/bin/env bash
# Fails when an evidence file holds a fixtures identifier, an email, a link or anything token-shaped. Prints counts only.
source "$(dirname "$0")/lib.sh"
D="evidence/$STAMP"
PAT=$(jq -r '[.workspace, .repository] | join("\n")' .local/fixtures.json)
ids=$( (grep -rilFf <(printf '%s\n' "$PAT") "$D" || true) | wc -l | tr -d ' ')
other=$( (grep -rlE 'bitbucket\.org|@[a-z0-9-]+\.[a-z]{2,}|https?://|ATATT|ATCTT|[0-9]{12}' "$D" || true) | wc -l | tr -d ' ')
keys=$( (grep -rlE '"key": *"[A-Z][A-Z0-9]+"' "$D" || true) | wc -l | tr -d ' ')
hrefs=$( { grep -rE '"href"' "$D" | grep -vE '"href": *"…"' | cut -d: -f1 | sort -u || true; } | wc -l | tr -d ' ')
hex40=$( (grep -rlE '[0-9a-f]{40}' "$D" || true) | wc -l | tr -d ' ')
echo "files with a fixtures identifier: $ids; files with an email, link, token or 12-digit shape: $other; files with a project-key shape: $keys; files with an href not masked whole: $hrefs; files with a 40-hex string: $hex40"
[[ "$ids" == 0 && "$other" == 0 && "$keys" == 0 && "$hrefs" == 0 && "$hex40" == 0 ]]
