# bitbucket-sim

A harness that runs scripted pull request scenarios against the real Bitbucket Cloud fixtures repository, as bot identities, and records masked evidence. It records how Bitbucket answers on a repository with multiple required approvals, default-reviewer approval and enforced merge checks. Enforced merge checks need the Premium plan. Use a throwaway repository: the scenarios merge into its default branch.

## Layout

- `bitbucket-bots.ts`: the CLI (`open`, `conflict`, `approve`, `unapprove`, `comment`, `close`, `status`, `merge`, `read`).
- `bot1.sh`, `bot2.sh`, `bot3.sh`: wrappers. `bot3` is the pull request author, so that bot1 and bot2 never approve their own work. Give bot3 webhook scopes as well, because it registers the hook.
- `mask.ts`: the evidence masking (masked by default, with a list of kept keys). Test: `pnpm test`.
- `receiver.ts`: the local webhook receiver on port 8787.
- `scenarios/`: S1 to S9, `lib.sh` and `hygiene.sh`.
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
7. Start the receiver: `pnpm exec tsx receiver.ts <stamp>`.
8. Run `./tunnel.sh`. It starts the tunnel and points the hook at it. A new tunnel gives a new URL, so run it again after a restart.

## Running

With `aws-vault` able to use your profile:

```
STAMP=<stamp> scenarios/s1.sh
STAMP=<stamp> scenarios/hygiene.sh
```

Each `<bot>.sh` call reads the credential from SSM into its own process. S2, S5 to S9 merge into the fixtures default branch. S9 adds `FILES` files (default 1500).

## Never

A token in a file, a log, a transcript or an argument; a write outside the fixtures repository; an AWS write from the harness; an unmasked workspace, repository, user id or email in any output. Evidence is git-ignored.
