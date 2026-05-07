export const parseTaskSchema = {
  type: "object",
  additionalProperties: false,
  required: ["tasks", "warnings", "friendlySummary", "needsReview"],
  properties: {
    tasks: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: [
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
        properties: {
          rawText: { type: "string" },
          cleanedTitle: { type: "string" },
          notes: { type: ["string", "null"] },
          category: {
            type: "string",
            enum: ["home", "errand", "family", "health", "money", "appointment", "meal", "cleaning", "personal", "reminder", "habit", "other"]
          },
          priority: {
            type: "string",
            enum: ["low", "normal", "high", "mustDo"]
          },
          energyLevel: {
            type: ["string", "null"],
            enum: ["low", "medium", "high", "brainTired", "bodyRestless", "quickWin", "calm", null]
          },
          estimatedMinutes: {
            type: "integer",
            minimum: 1,
            maximum: 480
          },
          preferredDate: { type: ["string", "null"], format: "date-time" },
          preferredDayOfWeek: {
            type: ["string", "null"],
            enum: ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", null]
          },
          preferredWindow: {
            type: ["string", "null"],
            enum: ["morning", "midday", "afternoon", "afterWork", "evening", "beforeBed", "anytime", null]
          },
          flexibleWindowLabel: { type: ["string", "null"] },
          dueDate: { type: ["string", "null"], format: "date-time" },
          isRecurring: { type: "boolean" },
          recurrenceRule: { type: ["string", "null"] },
          tinyStep: { type: ["string", "null"] },
          shrinkOptions: {
            type: "array",
            items: { type: "string" }
          },
          confidence: {
            type: "number",
            minimum: 0,
            maximum: 1
          },
          needsReview: { type: "boolean" },
          friendlyNote: { type: ["string", "null"] },
          scheduleRule: {
            type: "object",
            additionalProperties: false,
            required: [
              "canScheduleToday",
              "canScheduleThisWeek",
              "mustRespectDate",
              "mustRespectDay",
              "mustRespectWindow",
              "allowFlexiblePlacement"
            ],
            properties: {
              canScheduleToday: { type: "boolean" },
              canScheduleThisWeek: { type: "boolean" },
              mustRespectDate: { type: "boolean" },
              mustRespectDay: { type: "boolean" },
              mustRespectWindow: { type: "boolean" },
              allowFlexiblePlacement: { type: "boolean" }
            }
          }
        }
      }
    },
    warnings: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["code", "message", "taskTitle"],
        properties: {
          code: { type: "string" },
          message: { type: "string" },
          taskTitle: { type: ["string", "null"] }
        }
      }
    },
    friendlySummary: { type: "string" },
    needsReview: { type: "boolean" }
  }
};

export const buildScheduleSchema = {
  type: "object",
  additionalProperties: false,
  required: ["proposedBlocks", "unscheduledTaskIds", "carriedForwardTaskIds", "warnings", "friendlySummary"],
  properties: {
    proposedBlocks: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["taskId", "title", "startTime", "endTime", "flexibleWindowLabel", "category", "reminderStyle", "aiReason"],
        properties: {
          taskId: { type: ["string", "null"], format: "uuid" },
          title: { type: "string" },
          startTime: { type: "string", format: "date-time" },
          endTime: { type: "string", format: "date-time" },
          flexibleWindowLabel: { type: "string" },
          category: {
            type: "string",
            enum: ["home", "errand", "family", "health", "money", "appointment", "meal", "cleaning", "personal", "reminder", "habit", "other"]
          },
          reminderStyle: {
            type: "string",
            enum: ["none", "gentle", "timeSensitive", "alarmCandidate"]
          },
          aiReason: { type: ["string", "null"] }
        }
      }
    },
    unscheduledTaskIds: {
      type: "array",
      items: { type: "string", format: "uuid" }
    },
    carriedForwardTaskIds: {
      type: "array",
      items: { type: "string", format: "uuid" }
    },
    warnings: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["code", "message", "taskTitle"],
        properties: {
          code: { type: "string" },
          message: { type: "string" },
          taskTitle: { type: ["string", "null"] }
        }
      }
    },
    friendlySummary: { type: "string" }
  }
};
