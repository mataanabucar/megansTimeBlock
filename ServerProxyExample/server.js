import "dotenv/config";
import express from "express";
import OpenAI from "openai";
import { buildScheduleSchema, parseTaskSchema } from "./schemas.js";

const apiKey = process.env.OPENAI_API_KEY;
if (!apiKey) {
  throw new Error("Missing OPENAI_API_KEY. Keep this on the server only.");
}

const model = process.env.OPENAI_MODEL || "gpt-4.1-mini";
const port = Number(process.env.PORT || 8787);
const client = new OpenAI({ apiKey });

const app = express();
app.use(express.json({ limit: "1mb" }));

app.get("/health", (_request, response) => {
  response.json({ ok: true, model });
});

app.post("/parse-task", async (request, response) => {
  const { rawText, context } = request.body ?? {};
  if (typeof rawText !== "string" || !rawText.trim()) {
    response.status(400).json({ message: "Expected a non-empty rawText string." });
    return;
  }

  try {
    const parsed = await structuredOutput({
      name: "gentle_day_task_parse",
      schema: parseTaskSchema,
      systemPrompt: [
        "You are Gentle Day's task parser for a private ADHD-friendly time-blocking app.",
        "If the capture contains multiple independent tasks, return one candidate per task instead of merging them.",
        "Preserve natural timing intent from the raw text.",
        "If the user says Thursday evening, keep Thursday and evening as explicit constraints.",
        "Do not invent a morning slot for an evening task.",
        "Keep rawText unchanged and return only JSON that matches the schema."
      ].join(" "),
      payload: { rawText, context }
    });

    response.json(parsed);
  } catch (error) {
    console.error(error);
    response.status(502).json({ message: error.message || "Parse task request failed." });
  }
});

app.post("/build-schedule", async (request, response) => {
  const payload = request.body ?? {};
  if (!Array.isArray(payload.tasks) || !payload.preferences || !payload.range || !payload.style) {
    response.status(400).json({ message: "Expected tasks, preferences, range, and style in the request body." });
    return;
  }

  try {
    const plan = await structuredOutput({
      name: "gentle_day_schedule_build",
      schema: buildScheduleSchema,
      systemPrompt: [
        "You are Gentle Day's gentle planner for everyday life tasks.",
        "Respect preferredDate, preferredDayOfWeek, preferredWindow, and every mustRespect flag.",
        "Never move an evening task into the morning.",
        "Never move a Thursday task to another day unless allowFlexiblePlacement is true and you explain it in warnings.",
        "Prefer carried forward tasks over unsafe scheduling.",
        "Return only JSON that matches the schema."
      ].join(" "),
      payload
    });

    response.json(plan);
  } catch (error) {
    console.error(error);
    response.status(502).json({ message: error.message || "Build schedule request failed." });
  }
});

app.listen(port, () => {
  console.log(`Gentle Day proxy listening on http://localhost:${port}`);
});

async function structuredOutput({ name, schema, systemPrompt, payload }) {
  const result = await client.responses.create({
    model,
    input: [
      {
        role: "system",
        content: [{ type: "input_text", text: systemPrompt }]
      },
      {
        role: "user",
        content: [
          {
            type: "input_text",
            text: JSON.stringify(payload, null, 2)
          }
        ]
      }
    ],
    text: {
      format: {
        type: "json_schema",
        name,
        strict: true,
        schema
      }
    }
  });

  if (!result.output_text) {
    throw new Error("OpenAI returned no structured output text.");
  }

  return JSON.parse(result.output_text);
}
