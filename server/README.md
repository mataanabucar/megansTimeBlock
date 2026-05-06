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

By default the iOS simulator reads `GentleDayVoiceAPIBaseURL` from the generated Info.plist
and calls `http://localhost:8787/api/voice-dump`.

For a physical iPhone, use an HTTPS deployment URL or change `INFOPLIST_KEY_GentleDayVoiceAPIBaseURL`
in `GentleDay.xcodeproj/project.pbxproj` to a reachable HTTPS backend.
