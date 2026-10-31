/** The webhook receiver: answers 200 to every POST and records header names, the event key and a masked body. */
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

createServer((request, response) => {
  const chunks: Buffer[] = [];
  request.on('data', (chunk: Buffer) => chunks.push(chunk));
  request.on('end', () => {
    response.writeHead(200).end();
    if (request.method !== 'POST') return;
    const text = Buffer.concat(chunks).toString('utf8');
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
      headerNames: Object.keys(request.headers).sort(),
      body: maskAnswer(body, fixtures),
    })}\n`);
    console.log(`${String(eventKey)} pr=${pullRequest ?? '-'}`);
  });
}).listen(PORT, '127.0.0.1');
