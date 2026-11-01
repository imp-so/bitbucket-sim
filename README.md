# bitbucket-sim

A harness that runs scripted pull request scenarios against the real Bitbucket Cloud fixtures repository, as bot identities, and records masked evidence. It records how Bitbucket answers on a repository with multiple required approvals, default-reviewer approval and enforced merge checks. Enforced merge checks need the Premium plan. Use a throwaway repository: the scenarios merge into its default branch.

## Layout

- `bitbucket-bots.ts`: the CLI (`open`, `conflict`, `approve`, `unapprove`, `comment`, `close`, `status`, `merge`, `read`, and for round 2 `push`, `checks`, `request-changes`, `statuses`, `default-reviewers`).
- `bot1.sh`, `bot2.sh`, `bot3.sh`: wrappers. `bot3` is the pull request author, so that bot1 and bot2 never approve their own work. Give bot3 webhook scopes as well, because it registers the hook.
- `mask.ts`: the evidence masking (masked by default, with a list of kept keys). Test: `pnpm test`.
- `receiver.ts`: the local webhook receiver on port 8787.
- `scenarios/`: S1 to S12 and S14 to S16, `lib.sh` and `hygiene.sh`.
- `evidence/<stamp>/`: the masked answers per scenario and `deliveries.jsonl`.
- `.local/` (git-ignored): `fixtures.json` (copy `fixtures.example.json`) and the tunnel log.
- `tunnel.sh`: one shot. Starts the tunnel and registers the hook.

## Operator steps

Tokens are SSM parameters under `parameterPrefix`, read through `aws-vault` with the profile and region in `.local/fixtures.json`.

1. For each identity, create an Atlassian API token with scopes (app Bitbucket): `read:repository:bitbucket`, `write:repository:bitbucket`, `read:pullrequest:bitbucket`, `write:pullrequest:bitbucket`, `read:user:bitbucket`.
2. Store each one in your own terminal: `./store-bot.sh <bot> <email>`. The token goes through a hidden prompt and a private temp file.
3. Check each one: `node verify-bot.ts <bot>` prints the status of `GET /user` only.
4. Copy `fixtures.example.json` to `.local/fixtures.json` and fill it in. Do this before step 2.
5. In Bitbucket, on the fixtures repository: add bot1 as a default reviewer. On the default branch's rule, set two approvals and one approval from a default reviewer, and turn on "Prevent a merge with unresolved merge checks". The docs list that option as Premium only. Without it the rule only warns and merges go through.
6. Install with `NODE_OPTIONS=--use-system-ca pnpm install` if your machine's TLS inspection makes Node reject the registry.
7. Start the receiver: `pnpm exec tsx receiver.ts <stamp>`. `./signed-up.sh <stamp>` starts the receiver and the tunnel with a new webhook secret held only in their environment. `FAIL_EVENT=<event key> FAIL_ATTEMPTS=<n>` makes the receiver answer 500 to that event up to attempt n, to show Bitbucket's retries.
8. Run `./tunnel.sh`. It starts the tunnel and points the hook at it. A new tunnel gives a new URL, so run it again after a restart.

## Running

With `aws-vault` able to use your profile:

```
STAMP=<stamp> scenarios/s1.sh
STAMP=<stamp> scenarios/hygiene.sh
```

Each `<bot>.sh` call reads the credential from SSM into its own process. S2, S5 to S9 merge into the fixtures default branch. S9 adds `FILES` files (default 1500).

## Round 2 scenarios

S10 to S12 and S14 to S16 run the pull request cycle: required builds, a fix commit after approvals, a reviewer's change request, roles, an edit/edit conflict, a FAILED build at merge time. New verbs: `push --pr <id> [--file <path>] [--content <text>]` (one more commit on the source branch), `checks --pr <id>` (`mergeability/checks`), `request-changes --pr <id>` (a 404 or 405 is the finding), `statuses --pr <id>`, `default-reviewers`. `status --key <key>` posts a build under that key and name; the scenarios use `sim-build-a` and `sim-build-b`. Roles: bot3 is the author, bot2 the approver, bot1 the default reviewer.

The default branch's rule needs: two approvals, one of them from a default reviewer; "Reset approvals when the source branch is modified" on; "Prevent a merge with unresolved merge checks" on; at least two successful builds. S13 is the checks calls inside the others. A 5xx stops a scenario with exit 4 (one retry first, none for a merge). `steps.txt` lines end with a UTC time, to match deliveries to steps.

## Never

A token in a file, a log, a transcript or an argument; a write outside the fixtures repository; an AWS write from the harness; an unmasked workspace, repository, user id or email in any output. Evidence is git-ignored.

## Round 3

`STAMP=<stamp> scenarios/run.sh <scenario>` runs a scenario (arguments through the environment) only while the receiver answers on 127.0.0.1:8787, writes its output to `evidence/<stamp>/<scenario>.out`, and appends `<scenario> rc=<n> receiver=<up|down> <UTC time>` to `evidence/<stamp>/rc.txt`; it exits 5 when the receiver is down afterwards. `RUN_LABEL` names the line and the output file, for the S18 phases (`s18-prepare`). `hygiene.sh` also counts files holding a 40-hex string. `statuses_step` in `lib.sh` prints a count per build state and the total.

`fixtures/bitbucket-pipelines.yml` gives the repository two Pipelines steps, one posting a second status through the Pipelines proxy (unverified). It runs only on branches matching `sim/*-s18`, so the sim statuses of the other scenarios stay alone; no other scenario branch may end in `-s18`. `scenarios/s18-setup.sh` puts it on the default branch through a pull request.

S18 runs in three phases that share `evidence/<stamp>/s18`: `PHASE=prepare` (open, wait up to 10 minutes for two SUCCESSFUL builds, approvals, merge a mover; prints the pull request id and saves it to `pr.txt`), then the operator presses Sync, `PHASE=watch` (polls the head, statuses and checks every 30 s for up to 10 minutes), and `PHASE=after` (approve again if needed, merge, events). S19 to S22 cover an open change request, a push after one, the "No changes are requested" box and in-progress builds.
