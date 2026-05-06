# Gentle Day Voice API

Small local backend for OpenAI-powered voice dumps.

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

The app reads `GentleDayVoiceAPIBaseURL` from `GentleDay/Info.plist`.
For local iPhone testing, it currently points to:

```sh
http://Mataans-MacBook-Pro.local:8787
```

Keep the Mac and iPhone on the same Wi-Fi, leave this server running, and open
`http://Mataans-MacBook-Pro.local:8787/health` from Safari on the iPhone before testing the app.

Live dictation fills the app text area on-device with Apple Speech. When you stop speaking,
the app sends that text to `POST /api/voice-dump-text` for OpenAI task parsing. `POST /api/voice-dump`
is still available as an audio-upload fallback.

For production or testing away from home Wi-Fi, deploy this server behind HTTPS and change
`GENTLE_DAY_VOICE_API_BASE_URL` in `GentleDay.xcodeproj/project.pbxproj` to that URL.
