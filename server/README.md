# Mira import server

Reads calendar screenshots with Gemini for signed-in, premium Mira accounts.
The Gemini key lives only here (Secret Manager); the app never sees it.

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/v1/session` | Sign in with Apple identity token in body | Verifies the token with Apple's public keys and returns a 30-day session token plus the account (`premium`, `profile`) |
| GET | `/v1/account` | `Bearer <session>` | Current account |
| POST | `/v1/calendar-import` | `Bearer <session>`, premium only | `{ imageBase64, mimeType, today }` → `{ events: [...] }` |
| GET | `/healthz` | — | Liveness |

Accounts are listed in `ACCOUNTS` by Sign in with Apple user id (`sub`):

```json
{"001234.abcdef0123456789.0123": {"premium": true, "profile": "mira"}}
```

The app shows a person's user id under Settings → アカウント after they sign in, so it can be copied here.

## Configuration

| Variable | Required | Notes |
|---|---|---|
| `GEMINI_API_KEY` | yes | From Secret Manager |
| `SESSION_SECRET` | yes | ≥ 32 random bytes, from Secret Manager |
| `ACCOUNTS` | no | JSON above |
| `GEMINI_MODEL` | no | Default `gemini-3.8-flash` |
| `APPLE_BUNDLE_ID` | no | Default `jp.mugi.mira` |
| `DAILY_IMPORT_LIMIT` | no | Images per account per day, default 40 |

## Deploy to Cloud Run

```bash
gcloud services enable run.googleapis.com secretmanager.googleapis.com cloudbuild.googleapis.com
printf '%s' 'YOUR_GEMINI_KEY' | gcloud secrets create mira-gemini-key --data-file=-
openssl rand -base64 48 | tr -d '\n' | gcloud secrets create mira-session-secret --data-file=-

gcloud run deploy mira-import \
  --source . \
  --region asia-northeast1 \
  --allow-unauthenticated \
  --max-instances 1 \
  --memory 512Mi \
  --set-secrets GEMINI_API_KEY=mira-gemini-key:latest,SESSION_SECRET=mira-session-secret:latest \
  --set-env-vars 'ACCOUNTS={"MIRA_SUB":{"premium":true,"profile":"mira"}}'
```

`--allow-unauthenticated` only opens the door to the service; every endpoint
except `/healthz` and `/v1/session` requires a session, and importing also
requires a premium account. `--max-instances 1` keeps the daily limit exact
and caps cost.

## Test

```bash
npm ci
npm test
```
