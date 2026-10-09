import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { after, before, describe, it } from 'node:test';
import { createApp } from '../src/app.js';
import { RESPONSE_SCHEMA, requestBody } from '../src/gemini.js';

const env = {
  SESSION_SECRET: 'x'.repeat(40),
  GEMINI_API_KEY: 'server-only-key',
  ACCOUNTS: JSON.stringify({ 'mira-sub': { premium: true, profile: 'mira' } }),
  DAILY_IMPORT_LIMIT: '2'
};

let geminiCalls = [];
const fakeGemini = async (url, init) => {
  geminiCalls.push({ url, init });
  const events = [{ title: '有馬記念', date: '2026-12-27', startTime: '15:40', allDay: false }];
  return new Response(JSON.stringify({
    candidates: [{ content: { parts: [{ text: JSON.stringify({ events }) }] } }]
  }), { status: 200 });
};
const fakeApple = async (token) => {
  if (token === 'apple-mira') return 'mira-sub';
  if (token === 'apple-other') return 'other-sub';
  throw new Error('bad');
};

let server;
let base;
before(async () => {
  server = createServer(createApp({ env, fetchImpl: fakeGemini, verifyApple: fakeApple }));
  await new Promise((resolve) => server.listen(0, resolve));
  base = `http://127.0.0.1:${server.address().port}`;
});
after(() => server.close());

const post = (path, body, token) => fetch(base + path, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
  body: JSON.stringify(body)
});

async function signIn(identityToken) {
  const response = await post('/v1/session', { identityToken });
  return { status: response.status, body: await response.json() };
}

describe('sessions', () => {
  it('rejects tokens Apple did not sign', async () => {
    const { status } = await signIn('forged');
    assert.equal(status, 401);
  });

  it('issues a session and reports premium and profile', async () => {
    const { status, body } = await signIn('apple-mira');
    assert.equal(status, 200);
    assert.ok(body.sessionToken.length > 20);
    assert.deepEqual(body.account, { premium: true, profile: 'mira' });

    const account = await fetch(`${base}/v1/account`, { headers: { Authorization: `Bearer ${body.sessionToken}` } });
    assert.deepEqual((await account.json()).account, { premium: true, profile: 'mira' });
  });

  it('treats unknown people as standard, non-premium accounts', async () => {
    const { body } = await signIn('apple-other');
    assert.deepEqual(body.account, { premium: false, profile: 'standard' });
  });
});

describe('calendar import', () => {
  it('needs a session', async () => {
    const response = await post('/v1/calendar-import', { imageBase64: 'abc' });
    assert.equal(response.status, 401);
  });

  it('is premium only', async () => {
    const { body } = await signIn('apple-other');
    const response = await post('/v1/calendar-import', { imageBase64: 'abc' }, body.sessionToken);
    assert.equal(response.status, 403);
  });

  it('reads plans with the server-held key and enforces the daily limit', async () => {
    geminiCalls = [];
    const { body } = await signIn('apple-mira');
    const first = await post('/v1/calendar-import', { imageBase64: 'abc', today: '2026-10-10' }, body.sessionToken);
    assert.equal(first.status, 200);
    assert.equal((await first.json()).events[0].title, '有馬記念');
    assert.equal(geminiCalls[0].init.headers['x-goog-api-key'], 'server-only-key');
    assert.match(geminiCalls[0].url, /gemini-3\.8-flash:generateContent$/);

    await post('/v1/calendar-import', { imageBase64: 'abc' }, body.sessionToken);
    const third = await post('/v1/calendar-import', { imageBase64: 'abc' }, body.sessionToken);
    assert.equal(third.status, 429);
  });

  it('never leaks the key in errors', async () => {
    const failing = createApp({
      env: { ...env, DAILY_IMPORT_LIMIT: '9' },
      verifyApple: fakeApple,
      fetchImpl: async () => new Response(JSON.stringify({ error: { message: 'API key server-only-key invalid' } }), { status: 400 })
    });
    const local = createServer(failing);
    await new Promise((resolve) => local.listen(0, resolve));
    const localBase = `http://127.0.0.1:${local.address().port}`;
    const session = await (await fetch(`${localBase}/v1/session`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ identityToken: 'apple-mira' })
    })).json();
    const response = await fetch(`${localBase}/v1/calendar-import`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${session.sessionToken}` },
      body: JSON.stringify({ imageBase64: 'abc' })
    });
    const text = await response.text();
    local.close();
    assert.equal(response.status, 502);
    assert.ok(!text.includes('server-only-key'));
  });
});

describe('gemini request', () => {
  it('asks for schema-shaped JSON with the image inline', () => {
    const body = requestBody({ imageBase64: 'abc', mimeType: 'image/jpeg', today: '2026-10-10' });
    assert.equal(body.generationConfig.responseMimeType, 'application/json');
    assert.deepEqual(body.generationConfig.responseSchema, RESPONSE_SCHEMA);
    assert.equal(body.contents[0].parts[1].inlineData.data, 'abc');
    assert.match(body.contents[0].parts[0].text, /2026-10-10/);
  });
});

describe('configuration', () => {
  it('refuses to start without secrets', () => {
    assert.throws(() => createApp({ env: { GEMINI_API_KEY: 'k', SESSION_SECRET: 'short' } }));
    assert.throws(() => createApp({ env: { SESSION_SECRET: 'x'.repeat(40) } }));
  });
});
