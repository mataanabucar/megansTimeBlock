import "dotenv/config";

import cors from "cors";
import express from "express";
import fs from "fs/promises";
import { createReadStream } from "fs";
import multer from "multer";
import OpenAI from "openai";
import { toFile } from "openai/uploads";

const port = Number(process.env.PORT || 8787);
const upload = multer({
  dest: "uploads/",
  limits: {
    fileSize: 25 * 1024 * 1024
  }
});

const app = express();
app.use(cors());
app.use(express.json());

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY
});

const taskCategories = [
  "home",
  "errand",
  "family",
  "money",
  "appointment",
  "cleaning",
  "wellness",
  "meals",
  "bills",
  "routine",
  "lifeAdmin",
  "other"
];

const supportedAudioExtensions = new Set(["mp3", "mp4", "mpeg", "mpga", "m4a", "wav", "webm"]);

const taskSchema = {
  type: "object",
  additionalProperties: false,
  required: ["transcript", "tasks", "needs_review"],
  properties: {
    transcript: {
      type: "string",
      description: "The full transcript used for parsing, including any typed context."
    },
    tasks: {
      type: "array",
      description: "Every distinct task found in the transcript.",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["title", "category", "original_phrase", "estimated_minutes", "confidence"],
        properties: {
          title: {
            type: "string",
            description: "Short actionable task title in sentence case."
          },
          category: {
            type: "string",
            enum: taskCategories
          },
          original_phrase: {
            type: "string",
            description: "The words from the transcript that produced this task."
          },
          estimated_minutes: {
            type: "integer",
            minimum: 1,
            maximum: 240
          },
          confidence: {
            type: "number",
            minimum: 0,
            maximum: 1
          }
        }
      }
    },
    needs_review: {
      type: "array",
      description: "Non-actionable or ambiguous fragments that should not be silently dropped.",
      items: {
        type: "string"
      }
    }
  }
};

app.get("/", (_request, response) => {
  response
    .type("text/plain")
    .send([
      "Gentle Day Voice API is running.",
      "",
      "Health check: GET /health",
      "Voice dump endpoint: POST /api/voice-dump"
    ].join("\n"));
});

app.get("/health", (_request, response) => {
  response.json({ ok: true });
});

app.post("/api/voice-dump", upload.single("audio"), async (request, response) => {
  if (!process.env.OPENAI_API_KEY) {
    response.status(500).json({ error: "OPENAI_API_KEY is not configured on the server." });
    return;
  }

  if (!request.file) {
    response.status(400).json({ error: "Upload an audio file in the 'audio' form field." });
    return;
  }

  try {
    const typedText = cleanText(request.body.typed_text || "");
    const transcription = await transcribeAudio(request.file);
    const transcript = [typedText, cleanText(transcription)]
      .filter(Boolean)
      .join("\n");

    if (!transcript) {
      response.status(422).json({ error: "No transcript was produced from the audio." });
      return;
    }

    const parsed = await parseVoiceDump(transcript);
    response.json(parsed);
  } catch (error) {
    console.error(error);
    response.status(500).json({
      error: error?.message || "Voice dump parsing failed."
    });
  } finally {
    await fs.rm(request.file.path, { force: true });
  }
});

async function transcribeAudio(uploadedFile) {
  const audioFile = await toFile(
    createReadStream(uploadedFile.path),
    supportedAudioFileName(uploadedFile),
    { type: supportedAudioMimeType(uploadedFile) }
  );

  const result = await openai.audio.transcriptions.create({
    file: audioFile,
    model: process.env.OPENAI_TRANSCRIBE_MODEL || "gpt-4o-mini-transcribe",
    response_format: "text",
    prompt: [
      "This is a casual, messy personal task voice dump.",
      "Preserve chores, errands, self-care, medications, appointments, family tasks, fragments, and repeated 'I need to' phrasing.",
      "Do not summarize."
    ].join(" ")
  });

  return typeof result === "string" ? result : result.text;
}

async function parseVoiceDump(transcript) {
  const result = await openai.responses.create({
    model: process.env.OPENAI_PARSE_MODEL || "gpt-4.1-mini",
    input: [
      {
        role: "system",
        content: [
          "You parse messy human speech into a task inbox.",
          "Extract every distinct task. Default to separate tasks unless the speaker clearly says items belong together.",
          "Do not merge unrelated errands, chores, medications, self-care, appointments, calls, family work, or admin tasks.",
          "Remove filler such as 'I need to', 'um', 'also', and 'and then', while preserving the action.",
          "If a fragment is probably a task, include it as a task with lower confidence rather than dropping it.",
          "Use needs_review only for ambiguous fragments that cannot be turned into a useful task title."
        ].join(" ")
      },
      {
        role: "user",
        content: transcript
      }
    ],
    text: {
      format: {
        type: "json_schema",
        name: "voice_dump_tasks",
        strict: true,
        schema: taskSchema
      }
    }
  });

  return JSON.parse(result.output_text);
}

function cleanText(value) {
  return String(value || "").trim();
}

function supportedAudioFileName(uploadedFile) {
  const originalName = String(uploadedFile?.originalname || "")
    .split(/[\\/]/)
    .pop();

  if (originalName && hasSupportedAudioExtension(originalName)) {
    return originalName;
  }

  const baseName = originalName?.replace(/\.[^.]+$/, "") || "voice-dump";
  return `${baseName}.${extensionForMimeType(uploadedFile?.mimetype) || "m4a"}`;
}

function hasSupportedAudioExtension(fileName) {
  const extension = String(fileName || "").split(".").pop()?.toLowerCase();
  return supportedAudioExtensions.has(extension);
}

function supportedAudioMimeType(uploadedFile) {
  const mimeType = String(uploadedFile?.mimetype || "").toLowerCase();
  return mimeType || "audio/m4a";
}

function extensionForMimeType(mimeType) {
  switch (String(mimeType || "").toLowerCase()) {
    case "audio/mpeg":
    case "audio/mp3":
      return "mp3";
    case "audio/mp4":
    case "audio/m4a":
    case "audio/x-m4a":
      return "m4a";
    case "audio/wav":
    case "audio/x-wav":
      return "wav";
    case "audio/webm":
      return "webm";
    default:
      return undefined;
  }
}

app.listen(port, () => {
  console.log(`Gentle Day Voice API listening on http://localhost:${port}`);
});
