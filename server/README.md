# Gentle Day Local Development AI Proxy

Optional local backend for OpenAI-powered task parsing during development. Normal iPhone use should point at the hosted Vercel proxy from the main README.

## Setup

```sh
cd server
cp .env.example .env
```

Add your OpenAI API key to `server/.env`:

```sh
OPENAI_API_KEY=sk-...
```

Install dependencies and start the server:

```sh
npm install
npm run dev
```

In Gentle Day Settings, set `AI Proxy Endpoint URL` to your local development endpoint only when you intentionally want to test against your Mac:

```sh
http://<mac-wifi-ip>:8787/api/parse-task
```

Keep the Mac and iPhone on the same Wi-Fi, leave this server running, and open
`http://<mac-wifi-ip>:8787/health` from Safari on the iPhone before testing the app.

Live dictation fills the app text area on-device with Apple Speech. When you stop speaking,
the app sends that text to the configured AI proxy endpoint as `rawText`. For this local server,
use `POST /api/parse-task`. `POST /api/voice-dump-text` is kept only as a deprecated legacy endpoint,
and `POST /api/voice-dump` is still available as an audio-upload fallback.

For production or testing away from home Wi-Fi, use the stable hosted Vercel endpoint in
Gentle Day Settings:

```sh
https://gentle-day-ai-proxy.vercel.app/api/parse-task
```

Do not put an OpenAI API key in the iOS app.
