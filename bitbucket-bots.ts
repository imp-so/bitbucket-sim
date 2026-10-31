/** The bots' CLI: every verb acts on the one fixtures repository as `--as <bot>`, with the token read from SSM into
 *  this process. Each provider answer goes to the evidence masked, and the last one goes to stdout. */
import { execFile } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseArgs, promisify } from 'node:util';
import { credentialConfig, maskAnswer, readFixtures } from './mask.ts';

const API = 'https://api.bitbucket.org/2.0';
const POLL_INTERVAL_MS = 2_000;
const POLL_LIMIT = 60;
/** One `POST /src` of 1500 small files answered 500 (S9, first attempt). */
const FILES_PER_COMMIT = 250;
const HOOK_DESCRIPTION = 'bitbucket-sim-receiver';
const HOOK_EVENTS = [
  'pullrequest:created', 'pullrequest:updated', 'pullrequest:approved', 'pullrequest:unapproved',
  'pullrequest:fulfilled', 'pullrequest:rejected', 'pullrequest:comment_created', 'pullrequest:comment_updated',
  'pullrequest:comment_deleted', 'pullrequest:changes_request_created', 'pullrequest:changes_request_removed',
  'repo:push', 'repo:updated', 'repo:commit_status_created', 'repo:commit_status_updated',
];

const run = promisify(execFile);
const fixtures = credentialConfig(readFixtures());
const REPO = `${API}/repositories/${encodeURIComponent(fixtures.workspace)}/${encodeURIComponent(fixtures.repository)}`;

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    as: { type: 'string' },
    pr: { type: 'string' },
    name: { type: 'string' },
    title: { type: 'string' },
    branch: { type: 'string' },
    reviewer: { type: 'string', multiple: true },
    'default-reviewers': { type: 'boolean' },
    draft: { type: 'boolean' },
    files: { type: 'string' },
    path: { type: 'string' },
    content: { type: 'string' },
    text: { type: 'string' },
    state: { type: 'string' },
    key: { type: 'string' },
    strategy: { type: 'string' },
    'keep-source-branch': { type: 'boolean' },
    'url-file': { type: 'string' },
  },
});

const verb = positionals[0];
const bot = values.as ?? '';
if (!/^bot[0-9]$/.test(bot)) throw new Error('--as must name a bot');

const secrets: string[] = [];

async function parameter(botName: string, leaf: 'email' | 'token'): Promise<string> {
  const args = ['exec', fixtures.vaultProfile, '--no-session', '--', 'aws', 'ssm', 'get-parameter', '--region', fixtures.region,
    '--name', `${fixtures.parameterPrefix}/${botName}/${leaf}`, '--query', 'Parameter.Value', '--output', 'text'];
  if (leaf === 'token') args.push('--with-decryption');
  try {
    const { stdout } = await run('aws-vault', args);
    return stdout.trim();
  } catch {
    throw new Error(`could not read the ${leaf} of ${botName} (is the vault armed and the parameter present?)`);
  }
}

async function basicAuth(botName: string): Promise<string> {
  const [email, token] = await Promise.all([parameter(botName, 'email'), parameter(botName, 'token')]);
  if (!email || !token) throw new Error(`empty credential for ${botName}`);
  secrets.push(token, email);
  return `Basic ${Buffer.from(`${email}:${token}`).toString('base64')}`;
}

let authorization = '';
let step = 0;
const label = values.name ?? verb ?? 'call';
const evidenceDir = process.env.EVIDENCE_DIR;
if (evidenceDir) mkdirSync(evidenceDir, { recursive: true });

interface Answer {
  status: number;
  body: any;
  location?: string;
}

function record(method: string, path: string, answer: Answer): unknown {
  step += 1;
  const entry = maskAnswer(
    { bot, verb, label, step, request: { method, path }, status: answer.status, hasLocation: answer.location !== undefined, body: answer.body },
    fixtures,
    secrets,
  );
  if (evidenceDir) writeFileSync(join(evidenceDir, `${label}.${step}.json`), `${JSON.stringify(entry, null, 2)}\n`);
  return entry;
}

let last: unknown;

/** Evidence names the path by its last segments, since the leading ones hold the workspace and the repository. */
async function call(method: string, url: string, body?: unknown, auth = authorization): Promise<Answer> {
  const form = body instanceof URLSearchParams;
  const response = await fetch(url, {
    method,
    redirect: 'manual',
    headers: {
      Authorization: auth,
      Accept: 'application/json',
      ...(body !== undefined && !form ? { 'Content-Type': 'application/json' } : {}),
    },
    ...(body === undefined ? {} : { body: form ? body : JSON.stringify(body) }),
  });
  const text = await response.text();
  let parsed: unknown = text;
  try {
    parsed = text === '' ? null : JSON.parse(text);
  } catch {
    parsed = { nonJsonBytes: text.length };
  }
  const location = response.headers.get('location') ?? undefined;
  const answer: Answer = { status: response.status, body: parsed, ...(location ? { location } : {}) };
  const relative = url.startsWith(REPO) ? url.slice(REPO.length) || '/' : '<other>';
  last = record(method, relative, answer);
  return answer;
}

function need(name: string, value: string | undefined): string {
  if (!value) throw new Error(`${verb} needs --${name}`);
  return value;
}

const pullRequest = () => `${REPO}/pullrequests/${need('pr', values.pr)}`;

function must(answer: Answer, ...statuses: number[]): Answer {
  if (!statuses.includes(answer.status)) {
    console.log(JSON.stringify(last));
    process.exit(3);
  }
  return answer;
}

async function mainBranch(): Promise<{ name: string; hash: string }> {
  const repository = must(await call('GET', REPO), 200).body;
  const name: string = repository.mainbranch.name;
  const branch = must(await call('GET', `${REPO}/refs/branches/${encodeURIComponent(name)}`), 200).body;
  return { name, hash: branch.target.hash };
}

async function commitTo(branch: string, parent: string | undefined, files: Record<string, string>): Promise<void> {
  const form = new URLSearchParams({ branch, message: `sim: ${branch}`, ...(parent ? { parents: parent } : {}) });
  for (const [path, content] of Object.entries(files)) form.append(path, content);
  must(await call('POST', `${REPO}/src`, form), 201);
}

async function openOn(branch: string, main: string, reviewers: { uuid: string }[]): Promise<void> {
  const answer = await call('POST', `${REPO}/pullrequests`, {
    title: values.title ?? branch,
    source: { branch: { name: branch } },
    destination: { branch: { name: main } },
    reviewers,
    close_source_branch: true,
    ...(values.draft ? { draft: true } : {}),
  });
  must(answer, 201);
}

async function reviewerList(): Promise<{ uuid: string }[]> {
  const out: { uuid: string }[] = [];
  for (const reviewer of values.reviewer ?? []) {
    const auth = await basicAuth(reviewer);
    const user = must(await call('GET', `${API}/user`, undefined, auth), 200).body;
    out.push({ uuid: user.uuid });
  }
  if (values['default-reviewers']) {
    const listed = must(await call('GET', `${REPO}/effective-default-reviewers?pagelen=100`), 200).body;
    for (const entry of listed.values) out.push({ uuid: entry.user.uuid });
  }
  return out;
}

const verbs: Record<string, () => Promise<void>> = {
  async open() {
    const branch = need('branch', values.branch);
    const main = await mainBranch();
    const count = Number(values.files ?? 1);
    const files: Record<string, string> = {};
    for (let n = 0; n < count; n += 1) files[`${branch}/f${n}.txt`] = `file ${n}\n`;
    if (values.path) files[values.path] = `${values.content ?? branch}\n`;
    const paths = Object.keys(files);
    for (let start = 0; start < paths.length; start += FILES_PER_COMMIT) {
      const batch = Object.fromEntries(paths.slice(start, start + FILES_PER_COMMIT).map((path) => [path, files[path] ?? '']));
      await commitTo(branch, start === 0 ? main.hash : undefined, batch);
    }
    await openOn(branch, main.name, await reviewerList());
  },
  async conflict() {
    const branch = need('branch', values.branch);
    const main = await mainBranch();
    await commitTo(branch, main.hash, { [need('path', values.path)]: `${need('content', values.content)}\n` });
    await openOn(branch, main.name, []);
  },
  async approve() {
    await call('POST', `${pullRequest()}/approve`);
  },
  async unapprove() {
    await call('DELETE', `${pullRequest()}/approve`);
  },
  async comment() {
    await call('POST', `${pullRequest()}/comments`, { content: { raw: need('text', values.text) } });
  },
  async close() {
    await call('POST', `${pullRequest()}/decline`);
  },
  async status() {
    const pr = must(await call('GET', pullRequest()), 200).body;
    const commit = must(await call('GET', `${REPO}/commit/${pr.source.commit.hash}`), 200).body;
    await call('POST', `${REPO}/commit/${commit.hash}/statuses/build`, {
      key: values.key ?? 'sim-build',
      state: need('state', values.state),
      name: 'sim build',
      url: 'https://example.invalid/sim-build',
      description: 'the stand-in for CI',
    });
  },
  async merge() {
    const answer = await call('POST', `${pullRequest()}/merge`, {
      type: 'pullrequest',
      merge_strategy: values.strategy ?? 'merge_commit',
      close_source_branch: !values['keep-source-branch'],
    });
    if (answer.status !== 202 || !answer.location) return;
    for (let poll = 0; poll < POLL_LIMIT; poll += 1) {
      await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL_MS));
      const task = await call('GET', answer.location);
      if (task.body?.task_status !== 'PENDING') return;
    }
  },
  async read() {
    await call('GET', pullRequest());
  },
  /** Creates or re-points the harness's own hook, found by its description, at the URL in the tunnel log. */
  async webhook() {
    const log = readFileSync(need('url-file', values['url-file']), 'utf8');
    const url = log.match(/https:\/\/(?!api\.)[a-z0-9-]+\.trycloudflare\.com/)?.[0];
    if (!url) throw new Error('no tunnel URL in the log');
    const hooks = must(await call('GET', `${REPO}/hooks?pagelen=100`), 200).body;
    const mine = hooks.values.filter((hook: { description: string }) => hook.description === HOOK_DESCRIPTION);
    if (mine.length > 1 || hooks.next) throw new Error('more than one candidate hook; nothing changed');
    const body = { description: HOOK_DESCRIPTION, url, active: true, events: HOOK_EVENTS };
    if (mine.length === 1) must(await call('PUT', `${REPO}/hooks/${encodeURIComponent(mine[0].uuid)}`, body), 200);
    else must(await call('POST', `${REPO}/hooks`, body), 200, 201);
  },
};

const action = verb ? verbs[verb] : undefined;
if (!action) throw new Error(`unknown verb; one of ${Object.keys(verbs).join(', ')}`);
authorization = await basicAuth(bot);
await action();
console.log(JSON.stringify(last));
