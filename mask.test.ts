import assert from 'node:assert/strict';
import { test } from 'node:test';
import { maskAnswer } from './mask.ts';

const fixtures = { workspace: 'acme-ws', repository: 'fixture-repo' };

test('keeps ids, states and roles; masks names, links and account ids', () => {
  const out = maskAnswer(
    {
      id: 7,
      state: 'OPEN',
      author: { display_name: 'Some Person', uuid: '{1111-2222-3333}', account_id: '5f0000aaaabbbb' },
      links: { self: { href: 'https://api.example.test/2.0/repositories/acme-ws/fixture-repo/pullrequests/7' } },
      participants: [{ role: 'REVIEWER', approved: true }],
      merge_commit: { hash: 'abcdef0123456789abcdef0123456789abcdef01' },
    },
    fixtures,
  );
  assert.deepEqual(out, {
    id: 7,
    state: 'OPEN',
    author: { display_name: '…rson', uuid: '…333}', account_id: '…bbbb' },
    links: { self: { href: '…ts/7' } },
    participants: [{ role: 'REVIEWER', approved: true }],
    merge_commit: { hash: '…ef01(40)' },
  });
});

test('an unknown string field is masked by default', () => {
  assert.deepEqual(maskAnswer({ brand_new_field: 'a value nobody listed' }, fixtures), { brand_new_field: '…sted' });
});

test('a short value is masked whole', () => {
  assert.deepEqual(maskAnswer({ nickname: 'bot1' }, fixtures), { nickname: '…' });
});

test('free text in an error loses the workspace, the repository, a person, a link, an email and a secret', () => {
  const answer = {
    author: { display_name: 'Some Person' },
    error: {
      message: 'Some Person cannot merge acme-ws/FIXTURE-REPO at https://x.example.test/a from a@b.example with hunter22',
      fields: { newstatus: ['This pull request is already closed.'] },
    },
  };
  const text = JSON.stringify(maskAnswer(answer, fixtures, ['hunter22']));
  for (const leak of ['Some Person', 'acme-ws', 'FIXTURE-REPO', 'example.test', 'a@b.example', 'hunter22']) {
    assert.equal(text.includes(leak), false, leak);
  }
  assert.ok(text.includes('newstatus'));
  assert.ok(text.includes('already closed'));
});

test('a slug inside an ordinary word stays', () => {
  const out = maskAnswer({ error: { message: 'repository-wide check' } }, { workspace: 'repo', repository: 'repository' });
  assert.deepEqual(out, { error: { message: 'repository-wide check' } });
});

test('a project key is masked and the harness\'s build key stays', () => {
  const out = maskAnswer({ project: { key: 'ABC' }, commit_status: { key: 'sim-build' } }, fixtures);
  assert.deepEqual(out, { project: { key: '…' }, commit_status: { key: 'sim-build' } });
});
