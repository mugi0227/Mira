import { SignJWT, createRemoteJWKSet, jwtVerify } from 'jose';

const APPLE_ISSUER = 'https://appleid.apple.com';
const SESSION_ISSUER = 'mira-import-server';
const appleKeys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'));

/** Verifies a Sign in with Apple identity token for this app; returns the stable user id. */
export async function verifyAppleIdentityToken(token, { bundleId, keys = appleKeys }) {
  const { payload } = await jwtVerify(token, keys, { issuer: APPLE_ISSUER, audience: bundleId });
  if (typeof payload.sub !== 'string' || payload.sub.length === 0) throw new Error('missing subject');
  return payload.sub;
}

/** Apple identity tokens last ten minutes; the app keeps this longer session instead. */
export async function issueSession(sub, { secret, days = 30, now = Date.now() }) {
  const issuedAt = Math.floor(now / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(sub)
    .setIssuer(SESSION_ISSUER)
    .setIssuedAt(issuedAt)
    .setExpirationTime(issuedAt + days * 86400)
    .sign(secret);
}

export async function verifySession(token, { secret, now = Date.now() }) {
  const { payload } = await jwtVerify(token, secret, {
    issuer: SESSION_ISSUER,
    algorithms: ['HS256'],
    currentDate: new Date(now)
  });
  return payload.sub;
}
