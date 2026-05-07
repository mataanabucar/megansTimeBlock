# ServerProxyExample

This is an optional local development proxy example for Gentle Day.

It keeps `OPENAI_API_KEY` on the server and exposes JSON-only endpoints that the iOS app can call. For normal personal use on iPhone, deploy the same idea to a hosted HTTPS endpoint instead of depending on your Mac.

## Endpoints

- `POST /parse-task`
- `POST /build-schedule`
- `GET /health`

## Local Setup

1. Install dependencies:

```bash
npm install
```

2. Create a real local `.env` file:

```bash
cp .env.example .env
```

3. Open `.env` and replace the placeholder key:

```dotenv
OPENAI_API_KEY=sk-your-real-openai-key-here
OPENAI_MODEL=gpt-4.1-mini
PORT=8787
```

4. Start the proxy:

```bash
npm run dev
```

This example uses a plain Node start command so it works on older local Node versions too.

5. Use one of these app settings values:

- `http://localhost:8787/parse-task`
- `http://localhost:8787`
- `http://<mac-wifi-ip>:8787/parse-task`

If the app sees a full parse endpoint URL, it uses that for parse requests and derives `/build-schedule` beside it.

If you prefer not to use a `.env` file, you can still export the variables in your shell before running `npm run dev`.

## Notes

- The iOS app should never store the OpenAI API key.
- The local `.env` file should stay private and out of git.
- Local endpoints are for development only. Use a hosted HTTPS proxy for everyday use away from your Mac.
- This example has no auth, database, or deployment setup.
- Treat it as a starting point for a private personal backend, not as production infrastructure.
