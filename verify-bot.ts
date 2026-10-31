/** Read-only check of one bot's stored credential: prints the status of GET /user and nothing of the answer. */
import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import { credentialConfig, readFixtures } from './mask.ts';

const run = promisify(execFile);
const { vaultProfile, region, parameterPrefix } = credentialConfig(readFixtures());
const bot = process.argv[2] ?? '';
if (!/^bot[0-9]$/.test(bot)) throw new Error('usage: verify-bot.ts <bot>');

async function parameter(leaf: string): Promise<string> {
  const { stdout } = await run('aws-vault', ['exec', vaultProfile, '--no-session', '--', 'aws', 'ssm', 'get-parameter',
    '--region', region, '--name', `${parameterPrefix}/${bot}/${leaf}`,
    '--with-decryption', '--query', 'Parameter.Value', '--output', 'text']);
  return stdout.trim();
}

const [email, token] = await Promise.all([parameter('email'), parameter('token')]);
const authorization = `Basic ${Buffer.from(`${email}:${token}`).toString('base64')}`;
const response = await fetch('https://api.bitbucket.org/2.0/user', { headers: { Authorization: authorization }, redirect: 'manual' });
console.log(`${bot}: GET /user ${response.status}`);
