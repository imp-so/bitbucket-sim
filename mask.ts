/** The evidence rule: an answer keeps its ids, states and key names; every other string is masked to its last
 *  four characters. The default is masked, so a field Bitbucket adds later never reaches the evidence in clear. */
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

export const HERE = import.meta.dirname;

export interface Fixtures {
  workspace: string;
  repository: string;
  /** The aws-vault profile, region and SSM prefix that hold the bots' credentials. */
  vaultProfile?: string;
  region?: string;
  parameterPrefix?: string;
}

/** Operator-written and git-ignored, so the workspace reaches no argument, transcript or committed file. */
export function readFixtures(): Fixtures {
  const parsed = JSON.parse(readFileSync(join(HERE, '.local', 'fixtures.json'), 'utf8')) as Partial<Fixtures>;
  if (!parsed.workspace || !parsed.repository) throw new Error('.local/fixtures.json lacks workspace or repository');
  return parsed as Fixtures;
}

const KEPT_KEYS = new Set([
  'approved', 'close_source_branch', 'comment_count', 'created_on', 'date', 'draft', 'event', 'id', 'kind', 'label',
  'method', 'verb',
  'merge_strategies', 'merge_strategy', 'default_merge_strategy', 'queued', 'reason', 'role', 'state', 'status',
  'task_count', 'task_status', 'title', 'type', 'updated_on',
]);
const IDENTITY_KEYS = new Set(['account_id', 'display_name', 'nickname', 'username', 'uuid', 'email', 'slug', 'full_name']);
const HASH_KEYS = new Set(['hash']);
const FREE_TEXT_PARENTS = new Set(['error', 'fields']);

export function credentialConfig(fixtures: Fixtures): Required<Fixtures> {
  const { vaultProfile, region, parameterPrefix } = fixtures;
  if (!vaultProfile || !region || !parameterPrefix) throw new Error('.local/fixtures.json lacks vaultProfile, region or parameterPrefix');
  return { ...fixtures, vaultProfile, region, parameterPrefix };
}

export function masked(value: string): string {
  return value.length > 8 ? `…${value.slice(-4)}` : '…';
}

function escaped(literal: string): string {
  return literal.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/** Whole occurrences only, so a short slug never eats part of an ordinary word. */
function sweep(text: string, literals: string[]): string {
  let out = text.replace(/https?:\/\/[^\s"')]+/g, '<url>').replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '<email>').replace(/\b[0-9a-f]{40}\b/g, '<hash>');
  for (const literal of literals) {
    const bounded = new RegExp(`(?<![A-Za-z0-9._-])${escaped(literal)}(?![A-Za-z0-9._-])`, 'gi');
    out = out.replace(bounded, () => '<masked>');
  }
  return out;
}

function collectIdentities(value: unknown, into: Set<string>): void {
  if (Array.isArray(value)) {
    for (const item of value) collectIdentities(item, into);
  } else if (value !== null && typeof value === 'object') {
    for (const [key, inner] of Object.entries(value)) {
      if (IDENTITY_KEYS.has(key) && typeof inner === 'string' && inner.length > 0) into.add(inner);
      collectIdentities(inner, into);
    }
  }
}

function walk(value: unknown, key: string, parents: string[], literals: string[]): unknown {
  if (Array.isArray(value)) return value.map((item) => walk(item, key, parents, literals));
  if (value !== null && typeof value === 'object') {
    const out: Record<string, unknown> = {};
    for (const [inner, innerValue] of Object.entries(value)) {
      out[sweep(inner, literals)] = walk(innerValue, inner, [...parents, key], literals);
    }
    return out;
  }
  if (typeof value !== 'string') return value;
  // Last-four masking of a link leaked a project key (round 1), so a link goes whole.
  if (key === 'href') return '…';
  if (HASH_KEYS.has(key)) return `…${value.slice(-4)}(${value.length})`;
  if (value.startsWith('sim/') || value.startsWith('sim-')) return sweep(value, literals);
  const freeText = parents.some((parent) => FREE_TEXT_PARENTS.has(parent)) || key === 'error';
  if (KEPT_KEYS.has(key) || freeText) return sweep(value, literals);
  return masked(value);
}

export function maskAnswer(answer: unknown, fixtures: Fixtures, secrets: string[] = []): unknown {
  const identities = new Set<string>();
  collectIdentities(answer, identities);
  const literals = [fixtures.workspace, fixtures.repository, ...secrets, ...identities]
    .filter((literal) => literal.length > 0)
    .sort((a, b) => b.length - a.length);
  return walk(answer, '', [], literals);
}
