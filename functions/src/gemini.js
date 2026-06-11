// functions/src/gemini.js
//
// Firebase Cloud Function: callGemini
//
// Proxies Gemini API calls server-side so the key is never exposed to clients.
// Per-user rate limit: 15 RPM using a Firestore sliding-window counter.
//
// Deploy: firebase deploy --only functions:callGemini   (works on Spark plan)
//
// API key setup (no Secrets Manager needed — works on free Spark plan):
//   In Firebase Console → Firestore, create document:
//     Collection: _server_config   Document ID: gemini   Field: apiKey (string)
//   Set Firestore rules to deny client reads on _server_config (see firestore.rules).
//
// Flutter: call via cloud_functions package — request.auth is set automatically.

const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");

// Cached in-memory after first Firestore read — avoids a round-trip on every call.
let _cachedGeminiKey = null;

async function getGeminiKey(db) {
  if (_cachedGeminiKey) return _cachedGeminiKey;
  const doc = await db.collection("_server_config").doc("gemini").get();
  const key = doc.data()?.apiKey;
  if (!key) {
    throw new HttpsError(
      "failed-precondition",
      "Nur is not configured. Add the API key to Firestore: _server_config/gemini { apiKey: '...' }",
    );
  }
  _cachedGeminiKey = key;
  return key;
}

const RATE_LIMIT_RPM = 15;
const RATE_LIMIT_WINDOW_MS = 60 * 1000;
const GEMINI_MODEL = "gemini-2.0-flash";

async function checkRateLimit(db, uid) {
  const ref = db.collection("_nur_rate_limits").doc(uid);
  const now = Date.now();

  return db.runTransaction(async (tx) => {
    const doc = await tx.get(ref);
    const data = doc.exists ? doc.data() : null;
    const windowStart = data?.windowStart ?? 0;
    const count = data?.count ?? 0;

    if (now - windowStart > RATE_LIMIT_WINDOW_MS) {
      tx.set(ref, { windowStart: now, count: 1 });
      return true;
    }

    if (count >= RATE_LIMIT_RPM) {
      return false;
    }

    tx.update(ref, { count: admin.firestore.FieldValue.increment(1) });
    return true;
  });
}

async function callGeminiApi(apiKey, body) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${apiKey}`;
  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  if (!res.ok) {
    const text = await res.text();
    console.error("Gemini API error:", res.status, text);
    if (res.status === 429) {
      throw new HttpsError("resource-exhausted", "Gemini quota exceeded. Please try again tomorrow.");
    }
    throw new HttpsError("internal", "Gemini API unavailable.");
  }
  const json = await res.json();
  return json.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
}

exports.callGemini = onCall(
  { timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be signed in.");
    }

    const db = admin.firestore();
    const allowed = await checkRateLimit(db, request.auth.uid);
    if (!allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Nur rate limit reached (15 requests/minute). Please wait a moment.",
      );
    }

    const { mode, question, langCode, quranContext, hadithContext } =
      request.data ?? {};

    if (!mode || !question) {
      throw new HttpsError("invalid-argument", "mode and question are required.");
    }

    const apiKey = await getGeminiKey(db);

    // ── Mode A: keyword extraction ────────────────────────────────────────────
    if (mode === "keywords") {
      const prompt =
        `Extract 2-3 English search keywords from this Islamic question.\n` +
        `Always respond with English keywords, regardless of the question language.\n` +
        `Respond with ONLY this JSON (no markdown):\n` +
        `{"quranKeywords":["word1","word2"],"hadithKeywords":["word1","word2"]}\n\n` +
        `Question: ${question}`;

      const text = await callGeminiApi(apiKey, {
        contents: [{ parts: [{ text: prompt }] }],
        generationConfig: { responseMimeType: "application/json" },
      });

      if (!text) {
        return { quranKeywords: [question], hadithKeywords: [question] };
      }

      try {
        return JSON.parse(text);
      } catch {
        return { quranKeywords: [question], hadithKeywords: [question] };
      }
    }

    // ── Mode C: grounded explanation ─────────────────────────────────────────
    if (mode === "explain") {
      if (!quranContext || !hadithContext) {
        throw new HttpsError(
          "invalid-argument",
          "quranContext and hadithContext are required for explain mode.",
        );
      }

      const langNames = {
        en: "English",
        ar: "Arabic",
        ur: "Urdu",
        ru: "Russian",
        fa: "Persian (Farsi)",
        nl: "Dutch",
        zh: "Chinese",
      };
      const langName = langNames[langCode] ?? "English";

      const systemInstruction =
        `You are Nur, a compassionate and knowledgeable Islamic assistant.\n` +
        `You will be given authenticated Quran verses and Hadith texts from verified databases.\n` +
        `STRICTLY explain only the content provided. Do NOT reference any Quran verse or Hadith from your training memory.\n` +
        `If the provided content is insufficient, say so clearly — do not fill gaps.\n` +
        `Note scholarly differences (e.g. different madhabs) where they exist.\n` +
        `Always end your response with exactly this sentence on a new line:\n` +
        `"For personal fatwas, always consult a qualified Islamic scholar."\n` +
        `Respond in ${langName} language.\n` +
        `If the question is not about Islam, Quran, or Hadith, politely decline in ${langName}.\n` +
        `If asking for a personal ruling (e.g. "is MY divorce valid"), explain general guidance only and redirect to a scholar.`;

      const userPrompt =
        `Question: ${question}\n\n` +
        `=== QURAN EVIDENCE (from alquran.cloud — authenticated) ===\n${quranContext}\n\n` +
        `=== HADITH EVIDENCE (from fawazahmed0 canonical collections — authenticated) ===\n${hadithContext}\n\n` +
        `Provide:\n` +
        `1. explanation: A clear, scholarly explanation based ONLY on the above evidence.\n` +
        `2. quranContexts: An array of brief context notes, one per Quran verse above (same order, same count).\n` +
        `3. hadithContexts: An array of brief context notes, one per Hadith above (same order, same count).`;

      const responseSchema = {
        type: "object",
        properties: {
          explanation: { type: "string" },
          quranContexts: { type: "array", items: { type: "string" } },
          hadithContexts: { type: "array", items: { type: "string" } },
        },
      };

      const text = await callGeminiApi(apiKey, {
        systemInstruction: { parts: [{ text: systemInstruction }] },
        contents: [{ parts: [{ text: userPrompt }] }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema,
        },
      });

      if (!text) {
        return { explanation: "", quranContexts: [], hadithContexts: [] };
      }

      try {
        return JSON.parse(text);
      } catch {
        return { explanation: text, quranContexts: [], hadithContexts: [] };
      }
    }

    throw new HttpsError("invalid-argument", `Unknown mode: ${mode}`);
  },
);
