// functions/src/verifyImamDocuments.js
//
// Firebase Cloud Function that uses the Anthropic Claude API (vision)
// to compare an imam's CNIC/passport against their sanad/certificate.
//
// Deploy:  firebase deploy --only functions:verifyImamDocuments
//
// Required environment variable (set via Firebase secrets):
//   ANTHROPIC_API_KEY

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const Anthropic = require("@anthropic-ai/sdk");

const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

exports.verifyImamDocuments = onCall(
  { secrets: [anthropicKey], timeoutSeconds: 60 },
  async (request) => {
    // ── Auth guard ────────────────────────────────────────────────────────
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const { idCardBase64, sanadBase64 } = request.data;

    if (!idCardBase64 || !sanadBase64) {
      throw new HttpsError(
        "invalid-argument",
        "Both idCardBase64 and sanadBase64 are required.",
      );
    }

    // ── Basic size guard (5 MB each, base64 ~1.37× raw) ──────────────────
    const MAX_B64 = 7 * 1024 * 1024; // ~5 MB raw
    if (idCardBase64.length > MAX_B64 || sanadBase64.length > MAX_B64) {
      throw new HttpsError("invalid-argument", "Image too large (max 5 MB).");
    }

    // ── Detect media type from base64 header ──────────────────────────────
    function detectMediaType(b64) {
      if (b64.startsWith("/9j/")) return "image/jpeg";
      if (b64.startsWith("iVBOR")) return "image/png";
      if (b64.startsWith("R0lGO")) return "image/gif";
      if (b64.startsWith("UklGR")) return "image/webp";
      return "image/jpeg"; // fallback
    }

    const idMediaType = detectMediaType(idCardBase64);
    const sanadMediaType = detectMediaType(sanadBase64);

    // ── Call Claude Vision ────────────────────────────────────────────────
    const client = new Anthropic.default({
      apiKey: anthropicKey.value(),
    });

    const systemPrompt = `You are a document verification assistant for a mosque management app.
Your job is to compare two documents:
1. An identity document (CNIC, passport, or national ID)
2. A religious credential (sanad, ijazah, certificate of Islamic studies, or mosque appointment letter)

You must extract and compare names, check document authenticity indicators, and determine if the person in both documents is likely the same individual.

ALWAYS respond with ONLY a valid JSON object — no markdown, no explanation outside JSON.

JSON schema:
{
  "approved": boolean,
  "status": "approved" | "rejected" | "needs_review",
  "score": number (0-100),
  "reason": string (1-2 sentences, plain English),
  "nameMatchConfidence": number (0-100),
  "idCardName": string | null,
  "sanadName": string | null,
  "idCardValid": boolean,
  "sanadValid": boolean
}

Scoring guide:
- 80–100 → approved (names clearly match, both docs look genuine)
- 50–79  → needs_review (partial match or image quality issues)
- 0–49   → rejected (names don't match, or docs appear fake/unrelated)

Be lenient with transliteration differences (e.g. "Muhammad" vs "Mohammed").
If a document is unreadable, score it conservatively and set status to needs_review.`;

    let claudeResponse;
    try {
      claudeResponse = await client.messages.create({
        model: "claude-sonnet-4-20250514",
        max_tokens: 512,
        system: systemPrompt,
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: "Document 1 — Identity card / passport:",
              },
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: idMediaType,
                  data: idCardBase64,
                },
              },
              {
                type: "text",
                text: "Document 2 — Religious credential (sanad / certificate):",
              },
              {
                type: "image",
                source: {
                  type: "base64",
                  media_type: sanadMediaType,
                  data: sanadBase64,
                },
              },
              {
                type: "text",
                text: "Compare these two documents and return ONLY the JSON verdict.",
              },
            ],
          },
        ],
      });
    } catch (err) {
      console.error("Anthropic API error:", err);
      throw new HttpsError(
        "internal",
        "Document analysis service unavailable.",
      );
    }

    // ── Parse Claude's response ───────────────────────────────────────────
    const rawText = claudeResponse.content
      .filter((b) => b.type === "text")
      .map((b) => b.text)
      .join("");

    let verdict;
    try {
      // Strip any accidental markdown fences
      const clean = rawText.replace(/```json|```/g, "").trim();
      verdict = JSON.parse(clean);
    } catch (parseErr) {
      console.error("Failed to parse Claude response:", rawText);
      // Return a safe fallback
      return {
        approved: false,
        status: "needs_review",
        score: 0,
        reason:
          "Document analysis returned an unexpected format. Manual review required.",
        nameMatchConfidence: 0,
      };
    }

    // ── Sanitise and return ───────────────────────────────────────────────
    return {
      approved: verdict.approved === true,
      status: ["approved", "rejected", "needs_review"].includes(verdict.status)
        ? verdict.status
        : "needs_review",
      score: Math.min(100, Math.max(0, Number(verdict.score) || 0)),
      reason: String(verdict.reason || "No reason provided."),
      nameMatchConfidence: Math.min(
        100,
        Math.max(0, Number(verdict.nameMatchConfidence) || 0),
      ),
    };
  },
);
