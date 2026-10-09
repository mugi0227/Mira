import { DEFAULT_MODEL, readCalendarImage } from './gemini.js';
import { issueSession, verifyAppleIdentityToken, verifySession } from './auth.js';

const MAX_BODY_BYTES = 10 * 1024 * 1024;
const ALLOWED_MIME = new Set(['image/jpeg', 'image/png', 'image/heic', 'image/webp']);

/**
 * Accounts come from the ACCOUNTS env var, e.g.
 * {"001234.abcd...": {"premium": true, "profile": "mira"}}
 * keyed by the Sign in with Apple user id.
 */
export function parseAccounts(text) {
  if (!text) return {};
  try {
    const value = JSON.parse(text);
    return value && typeof value === 'object' ? value : {};
  } catch {
    return {};
  }
}

export function createApp({
  env,
  fetchImpl = fetch,
  verifyApple = verifyAppleIdentityToken,
  now = () => Date.now()
}) {
  const secret = new TextEncoder().encode(env.SESSION_SECRET ?? '');
  if (secret.length < 32) throw new Error('SESSION_SECRET must be at least 32 bytes');
  if (!env.GEMINI_API_KEY) throw new Error('GEMINI_API_KEY is required');
  const bundleId = env.APPLE_BUNDLE_ID ?? 'jp.mugi.mira';
  const accounts = parseAccounts(env.ACCOUNTS);
  const dailyLimit = Number(env.DAILY_IMPORT_LIMIT ?? 40);
  const model = env.GEMINI_MODEL || DEFAULT_MODEL;
  const usage = new Map();

  const accountFor = (sub) => {
    const entry = accounts[sub] ?? {};
    return { userId: sub, premium: entry.premium === true, profile: entry.profile ?? 'standard' };
  };

  // Per-instance daily count; Cloud Run with max-instances=1 makes it exact.
  const takeQuota = (sub) => {
    const day = new Date(now()).toISOString().slice(0, 10);
    const key = `${sub}:${day}`;
    const used = usage.get(key) ?? 0;
    if (used >= dailyLimit) return false;
    usage.set(key, used + 1);
    return true;
  };

  async function authenticate(request) {
    const header = request.headers.authorization ?? '';
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    if (!token) return null;
    try {
      return await verifySession(token, { secret, now: now() });
    } catch {
      return null;
    }
  }

  return async function handle(request, response) {
    const send = (status, body) => {
      response.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' });
      response.end(JSON.stringify(body));
    };
    try {
      const url = new URL(request.url, 'http://localhost');
      if (request.method === 'GET' && url.pathname === '/healthz') return send(200, { ok: true });

      if (request.method === 'POST' && url.pathname === '/v1/session') {
        const body = await readJSON(request);
        if (typeof body.identityToken !== 'string') return send(400, { error: 'identityToken is required' });
        let sub;
        try {
          sub = await verifyApple(body.identityToken, { bundleId });
        } catch {
          return send(401, { error: 'Apple sign-in could not be verified' });
        }
        const sessionToken = await issueSession(sub, { secret, now: now() });
        return send(200, { sessionToken, account: accountFor(sub) });
      }

      const sub = await authenticate(request);
      if (!sub) return send(401, { error: 'sign in again' });

      if (request.method === 'GET' && url.pathname === '/v1/account') {
        return send(200, { account: accountFor(sub) });
      }

      if (request.method === 'POST' && url.pathname === '/v1/calendar-import') {
        if (!accountFor(sub).premium) return send(403, { error: 'premium is required' });
        const body = await readJSON(request);
        const mimeType = body.mimeType ?? 'image/jpeg';
        if (typeof body.imageBase64 !== 'string' || body.imageBase64.length === 0) {
          return send(400, { error: 'imageBase64 is required' });
        }
        if (!ALLOWED_MIME.has(mimeType)) return send(400, { error: 'unsupported image type' });
        const today = /^\d{4}-\d{2}-\d{2}$/.test(body.today ?? '') ? body.today : new Date(now()).toISOString().slice(0, 10);
        if (!takeQuota(sub)) return send(429, { error: 'daily limit reached' });
        const result = await readCalendarImage({
          fetchImpl, apiKey: env.GEMINI_API_KEY, model, imageBase64: body.imageBase64, mimeType, today
        });
        return send(200, result);
      }

      return send(404, { error: 'not found' });
    } catch (error) {
      const status = Number.isInteger(error.status) ? error.status : 500;
      // Never echo provider details or credentials back to the client.
      return send(status, { error: status === 413 ? 'image too large' : 'could not read the calendar' });
    }
  };
}

async function readJSON(request) {
  let size = 0;
  const chunks = [];
  for await (const chunk of request) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) {
      const error = new Error('too large');
      error.status = 413;
      throw error;
    }
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}');
  } catch {
    const error = new Error('bad json');
    error.status = 400;
    throw error;
  }
}
