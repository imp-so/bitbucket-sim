#!/usr/bin/env bash
# S18 setup: puts fixtures/bitbucket-pipelines.yml on the default branch through a pull request, since the rule blocks a direct commit.
# The branch name does not match the S18 pattern, so no pipeline runs on it.
source "$(dirname "$0")/lib.sh"
START=$(delivery_count)
b "$AUTHOR" 01-open open --branch "sim/$RUN_ID-pipelines-setup" --title "S18 setup pipelines file" --path bitbucket-pipelines.yml --content "$(cat fixtures/bitbucket-pipelines.yml)" --default-reviewers; PR=$(pr_id)
b "$DEFAULT_REVIEWER" 02-status-a-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-a
b "$DEFAULT_REVIEWER" 03-status-b-default-reviewer status --pr "$PR" --state SUCCESSFUL --key sim-build-b
b "$DEFAULT_REVIEWER" 04-approve-default-reviewer approve --pr "$PR"
b "$APPROVER" 05-approve-approver approve --pr "$PR"
checks_step "$AUTHOR" 06-checks-approved "$PR"
b "$AUTHOR" 07-merge merge --pr "$PR"
events_since "$START" "$PR"
