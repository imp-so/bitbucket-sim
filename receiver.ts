/**
 * The webhook receiver: answers 200 to every POST and records header names, the event key, a masked body, hashes of the request
 * uuid and the raw body (compared across deliveries, never the values) and whether the signature verifies under WEBHOOK_SECRET.
 */
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';
import { appendFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { join } from 'node:path';
import { HERE, maskAnswer, readFixtures } from './mask.ts';

const PORT = 8787;
const stamp = process.argv[2];
if (!stamp) throw new Error('usage: receiver.ts <stamp>');

const fixtures = readFixtures();
const dir = join(HERE, 'evidence', stamp);
mkdirSync(dir, { recursive: true });
const deliveries = join(dir, 'deliveries.jsonl');
const secret = process.env.WEBHOOK_SECRET;
// S23: deliveries of this event key are answered 500 up to attempt FAIL_ATTEMPTS, so Bitbucket's own retries show.
const failEvent = process.env.FAIL_EVENT;
const failAttempts = Number(process.env.FAIL_ATTEMPTS ?? 3);

// base64url, so a hash never takes the 40-hex shape the hygiene script looks for.
const hash = (value: string | Buffer): string => createHash('sha256').update(value).digest('base64url');

function signatureVerdict(raw: Buffer, header: string | string[] | undefined): string {
  if (typeof header !== 'string') return 'absent';
  if (!secret) return 'no-secret';
  const expected = Buffer.from(`sha256=${createHmac('sha256', secret).update(raw).digest('hex')}`);
  const got = Buffer.from(header);
  return got.length === expected.length && timingSafeEqual(got, expected) ? 'valid' : 'invalid';
}

createServer((request, response) => {
  const chunks: Buffer[] = [];
  request.on('data', (chunk: Buffer) => chunks.push(chunk));
  request.on('end', () => {
    const fails = request.method === 'POST' && request.headers['x-event-key'] === failEvent
      && Number(request.headers['x-attempt-number']) <= failAttempts;
    const answered = fails ? 500 : 200;
    response.writeHead(answered).end();
    if (request.method !== 'POST') return;
    const raw = Buffer.concat(chunks);
    const text = raw.toString('utf8');
    const requestUuid = request.headers['x-request-uuid'];
    let body: any = { nonJsonBytes: text.length };
    try {
      body = JSON.parse(text);
    } catch {
      // A probe of the public tunnel URL is recorded by size alone.
    }
    const eventKey = request.headers['x-event-key'] ?? 'none';
    const pullRequest = body?.pullrequest?.id ?? null;
    appendFileSync(deliveries, `${JSON.stringify({
      at: new Date().toISOString(),
      eventKey,
      pullRequest,
      attempt: request.headers['x-attempt-number'] ?? null,
      answered,
      requestUuidHash: typeof requestUuid === 'string' ? hash(requestUuid) : null,
      bodySha256: hash(raw),
      signature: signatureVerdict(raw, request.headers['x-hub-signature']),
      headerNames: Object.keys(request.headers).sort(),
      body: maskAnswer(body, fixtures),
    })}\n`);
    console.log(`${String(eventKey)} pr=${pullRequest ?? '-'}`);
  });
}).listen(PORT, '127.0.0.1');
