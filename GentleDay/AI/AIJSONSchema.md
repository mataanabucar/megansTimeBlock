# Gentle Day Structured Output Schemas

These schemas are intended for OpenAI Structured Outputs on the server side. The iOS app should never call OpenAI directly and should never store the API key.

The examples below assume:

- `strict: true`
- lowercase enum values in JSON
- ISO-8601 strings for dates and datetimes

## Parse Task Request Payload

The iOS app sends the proxy JSON shaped like this:

```json
{
  "rawText": "Take out the trash on Thursday evening",
  "currentDate": "2026-05-06T22:30:00Z",
  "timezone": "America/New_York",
  "locale": "en_US",
  "planningDay": "today",
  "planningStyle": "balancedDay",
  "wakeTime": "2026-05-06T11:30:00Z",
  "sleepTime": "2026-05-07T02:30:00Z",
  "preferredReminderBehavior": "gentle",
  "defaultTaskDuration": 20,
  "existingTasks": [],
  "existingScheduleBlocks": [],
  "context": {
    "currentDate": "2026-05-06T22:30:00Z",
    "timezoneIdentifier": "America/New_York",
    "localeIdentifier": "en_US",
    "scheduleRange": "today",
    "planningStyle": "balancedDay",
    "userPreferences": {
      "wakeTime": "2026-05-06T11:30:00Z",
      "sleepTime": "2026-05-07T02:30:00Z",
      "defaultTaskDuration": 20,
      "defaultReminderStyle": "gentle"
    },
    "existingTasks": [],
    "existingScheduleBlocks": []
  }
}
```

The proxy should use this context to interpret relative phrases like "tomorrow," "tonight," and weekday names. The response must still match the strict schema below.

Note:

- Top-level fields are included for hosted proxies that prefer a flatter request contract. The nested `context` object remains for compatibility with the local development proxy example.
- The user prompt listed `Tuesday` with a capital `T`. The schema normalizes that to lowercase `tuesday` so every weekday enum value is consistent.
- The app still validates decoded values before saving, even when the response matches schema.

## Parse Task Response Schema

```json
{
  "name": "gentle_day_task_parse",
  "strict": true,
  "schema": {
    "type": "object",
    "additionalProperties": false,
    "required": ["tasks", "warnings", "friendlySummary", "needsReview"],
    "properties": {
      "tasks": {
        "type": "array",
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "rawText",
            "cleanedTitle",
            "category",
            "priority",
            "estimatedMinutes",
            "isRecurring",
            "shrinkOptions",
            "confidence",
            "needsReview",
            "scheduleRule"
          ],
          "properties": {
            "rawText": { "type": "string" },
            "cleanedTitle": { "type": "string" },
            "notes": { "type": ["string", "null"] },
            "category": {
              "type": "string",
              "enum": [
                "home",
                "errand",
                "family",
                "health",
                "money",
                "appointment",
                "meal",
                "cleaning",
                "personal",
                "reminder",
                "habit",
                "other"
              ]
            },
            "priority": {
              "type": "string",
              "enum": ["low", "normal", "high", "mustDo"]
            },
            "energyLevel": {
              "type": ["string", "null"],
              "enum": [
                "low",
                "medium",
                "high",
                "brainTired",
                "bodyRestless",
                "quickWin",
                "calm",
                null
              ]
            },
            "estimatedMinutes": {
              "type": "integer",
              "minimum": 1,
              "maximum": 480
            },
            "preferredDate": {
              "type": ["string", "null"],
              "format": "date-time"
            },
            "preferredDayOfWeek": {
              "type": ["string", "null"],
              "enum": [
                "monday",
                "tuesday",
                "wednesday",
                "thursday",
                "friday",
                "saturday",
                "sunday",
                null
              ]
            },
            "preferredWindow": {
              "type": ["string", "null"],
              "enum": [
                "morning",
                "midday",
                "afternoon",
                "afterWork",
                "evening",
                "beforeBed",
                "anytime",
                null
              ]
            },
            "flexibleWindowLabel": { "type": ["string", "null"] },
            "dueDate": {
              "type": ["string", "null"],
              "format": "date-time"
            },
            "isRecurring": { "type": "boolean" },
            "recurrenceRule": { "type": ["string", "null"] },
            "tinyStep": { "type": ["string", "null"] },
            "shrinkOptions": {
              "type": "array",
              "items": { "type": "string" }
            },
            "confidence": {
              "type": "number",
              "minimum": 0,
              "maximum": 1
            },
            "needsReview": { "type": "boolean" },
            "friendlyNote": { "type": ["string", "null"] },
            "scheduleRule": {
              "type": "object",
              "additionalProperties": false,
              "required": [
                "canScheduleToday",
                "canScheduleThisWeek",
                "mustRespectDate",
                "mustRespectDay",
                "mustRespectWindow",
                "allowFlexiblePlacement"
              ],
              "properties": {
                "canScheduleToday": { "type": "boolean" },
                "canScheduleThisWeek": { "type": "boolean" },
                "mustRespectDate": { "type": "boolean" },
                "mustRespectDay": { "type": "boolean" },
                "mustRespectWindow": { "type": "boolean" },
                "allowFlexiblePlacement": { "type": "boolean" }
              }
            }
          }
        }
      },
      "warnings": {
        "type": "array",
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": ["code", "message", "taskTitle"],
          "properties": {
            "code": { "type": "string" },
            "message": { "type": "string" },
            "taskTitle": { "type": ["string", "null"] }
          }
        }
      },
      "friendlySummary": { "type": "string" },
      "needsReview": { "type": "boolean" }
    }
  }
}
```

## Build Schedule Response Schema

```json
{
  "name": "gentle_day_schedule_build",
  "strict": true,
  "schema": {
    "type": "object",
    "additionalProperties": false,
    "required": [
      "proposedBlocks",
      "unscheduledTaskIds",
      "carriedForwardTaskIds",
      "warnings",
      "friendlySummary"
    ],
    "properties": {
      "proposedBlocks": {
        "type": "array",
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": [
            "taskId",
            "title",
            "startTime",
            "endTime",
            "flexibleWindowLabel",
            "category",
            "reminderStyle",
            "aiReason"
          ],
          "properties": {
            "taskId": { "type": ["string", "null"], "format": "uuid" },
            "title": { "type": "string" },
            "startTime": { "type": "string", "format": "date-time" },
            "endTime": { "type": "string", "format": "date-time" },
            "flexibleWindowLabel": { "type": "string" },
            "category": {
              "type": "string",
              "enum": [
                "home",
                "errand",
                "family",
                "health",
                "money",
                "appointment",
                "meal",
                "cleaning",
                "personal",
                "reminder",
                "habit",
                "other"
              ]
            },
            "reminderStyle": {
              "type": "string",
              "enum": ["none", "gentle", "timeSensitive", "alarmCandidate"]
            },
            "aiReason": { "type": ["string", "null"] }
          }
        }
      },
      "unscheduledTaskIds": {
        "type": "array",
        "items": { "type": "string", "format": "uuid" }
      },
      "carriedForwardTaskIds": {
        "type": "array",
        "items": { "type": "string", "format": "uuid" }
      },
      "warnings": {
        "type": "array",
        "items": {
          "type": "object",
          "additionalProperties": false,
          "required": ["code", "message", "taskTitle"],
          "properties": {
            "code": { "type": "string" },
            "message": { "type": "string" },
            "taskTitle": { "type": ["string", "null"] }
          }
        }
      },
      "friendlySummary": { "type": "string" }
    }
  }
}
```

## Prompting Notes For The Server

- Preserve raw capture text exactly in `rawText`.
- Convert phrases like `on Thursday evening` into `preferredDayOfWeek: "thursday"` and `preferredWindow: "evening"`.
- If a task is explicitly tied to a weekday, date, or time window, set the matching `mustRespect...` flag to `true`.
- If a task can move around safely, set `allowFlexiblePlacement` to `true`.
- For `this week`, prefer `canScheduleThisWeek: true` without inventing a fake exact date.
- Never invent a morning slot for an `evening` task, or another weekday for a task that explicitly belongs to Thursday unless the response also explains why it is flexible.
