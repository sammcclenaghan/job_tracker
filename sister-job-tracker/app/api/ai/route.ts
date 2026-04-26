import { NextRequest, NextResponse } from "next/server";

type ChatMessage = {
  role: "system" | "user" | "assistant";
  content: string;
};

const PARSING_MODEL =
  process.env.OPENROUTER_PARSING_MODEL || "openai/gpt-oss-120b:free";
const WRITING_MODEL =
  process.env.OPENROUTER_WRITING_MODEL ||
  "meta-llama/llama-3.3-70b-instruct:free";

function jsonError(message: string, status = 400) {
  return NextResponse.json({ error: message }, { status });
}

function stripMarkdownFences(text: string) {
  return text
    .replace(/^\s*```(?:json)?\s*/i, "")
    .replace(/\s*```\s*$/i, "")
    .trim();
}

async function openRouterChat({
  messages,
  model,
  temperature = 0.3,
  json = false,
  apiKey,
}: {
  messages: ChatMessage[];
  model: string;
  temperature?: number;
  json?: boolean;
  apiKey?: string;
}) {
  const selectedApiKey = apiKey || process.env.OPENROUTER_API_KEY;
  if (!selectedApiKey) {
    throw new Error(
      "Missing OpenRouter API key. Add one in Settings or set OPENROUTER_API_KEY in Vercel."
    );
  }

  const response = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${selectedApiKey}`,
      "Content-Type": "application/json",
      "HTTP-Referer": process.env.NEXT_PUBLIC_APP_URL || "https://jobtracker-theta-ebon.vercel.app",
      "X-Title": "Job Tracker",
    },
    body: JSON.stringify({
      model,
      messages,
      temperature,
      ...(json ? { response_format: { type: "json_object" } } : {}),
    }),
  });

  const payload = await response.json().catch(() => null);
  if (!response.ok) {
    const message =
      payload?.error?.message ||
      payload?.message ||
      `OpenRouter request failed with status ${response.status}`;
    throw new Error(message);
  }

  const content = payload?.choices?.[0]?.message?.content;
  if (!content) throw new Error("OpenRouter returned an empty response.");
  return content as string;
}

function profileBlock(profile: unknown, entries: unknown) {
  return JSON.stringify({ profile, experience_entries: entries }, null, 2);
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const action = body.action as string | undefined;
    const apiKey =
      typeof body.openRouterApiKey === "string"
        ? body.openRouterApiKey.trim()
        : undefined;

    if (action === "parse") {
      const rawContent = String(body.rawContent || "").trim();
      if (!rawContent) return jsonError("Paste a job posting first.");

      const content = await openRouterChat({
        model: PARSING_MODEL,
        apiKey,
        json: true,
        messages: [
          {
            role: "system",
            content:
              'You are a job posting parser. Return ONLY valid JSON with these keys: company_name, job_title, location, work_arrangement ("remote", "hybrid", "onsite", or null), salary_range, job_description, skills (array of strings), contact_email, application_instructions, job_url. Use null or [] when missing.',
          },
          { role: "user", content: rawContent },
        ],
      });

      return NextResponse.json(JSON.parse(stripMarkdownFences(content)));
    }

    if (action === "insights") {
      if (!body.application) return jsonError("Application is required.");

      const content = await openRouterChat({
        model: PARSING_MODEL,
        apiKey,
        json: true,
        temperature: 0.25,
        messages: [
          {
            role: "system",
            content:
              "You analyze job fit. Return ONLY valid JSON with keys: match_score (integer 0-100), match_reason (string), project_recommendations (array of strings naming the most relevant projects/experiences), experience_tailoring (array of concise strings), matching_skills (array of strings), missing_skills (array of strings). Be practical, kind, and specific.",
          },
          {
            role: "user",
            content: JSON.stringify(
              {
                application: body.application,
                profile_context: body.profile,
                experience_entries: body.entries || [],
              },
              null,
              2
            ),
          },
        ],
      });

      return NextResponse.json(JSON.parse(stripMarkdownFences(content)));
    }

    if (action === "cover_letter") {
      if (!body.application) return jsonError("Application is required.");

      const content = await openRouterChat({
        model: WRITING_MODEL,
        apiKey,
        temperature: 0.45,
        messages: [
          {
            role: "system",
            content:
              "You write warm, concise cover letters. Use the applicant's real profile evidence, do not invent facts, avoid stiff corporate language, and return only the letter text.",
          },
          {
            role: "user",
            content: [
              "Write a tailored cover letter for this application.",
              "",
              "Application:",
              JSON.stringify(body.application, null, 2),
              "",
              "Applicant profile and experience:",
              profileBlock(body.profile, body.entries || []),
              "",
              body.feedback
                ? `Regeneration feedback to follow: ${String(body.feedback)}`
                : "",
            ].join("\n"),
          },
        ],
      });

      return NextResponse.json({ cover_letter: content.trim() });
    }

    return jsonError("Unknown AI action.");
  } catch (error) {
    const message = error instanceof Error ? error.message : "AI request failed.";
    return jsonError(message, 500);
  }
}
