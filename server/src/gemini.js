// Asks Gemini to read a calendar screenshot and answer with schema-shaped JSON.
// Keep the prompt and schema in step with GeminiCalendarExtractor.swift.

export const DEFAULT_MODEL = 'gemini-3.8-flash';

export const RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    events: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING' },
          date: { type: 'STRING', description: 'yyyy-MM-dd' },
          endDate: { type: 'STRING', description: 'yyyy-MM-dd, multi-day only' },
          startTime: { type: 'STRING', description: 'HH:mm or empty' },
          endTime: { type: 'STRING', description: 'HH:mm or empty' },
          allDay: { type: 'BOOLEAN' },
          confidence: { type: 'NUMBER' }
        },
        required: ['title', 'date', 'allDay']
      }
    }
  },
  required: ['events']
};

export function prompt(today) {
  return [
    'これはカレンダー画面のスクリーンショット、またはPC画面を撮った写真です（斜め・ちらつき模様があっても読んでください）。',
    '画面に表示されている予定を、すべて抜き出してJSONで返してください。',
    `- まず画面上部の年月を読み、各日付を yyyy-MM-dd に直す。前後の月のグレーの日付も正しい年月にする。年が書かれていなければ ${today} に近い年。`,
    '- 時刻が書かれていれば startTime（HH:mm）。終了時刻があれば endTime。時刻がなければ allDay を true。',
    '- 何日にもまたがる帯は、始まりの日を date、終わりの日を endDate にする。',
    '- title は画面の文字どおり。時刻の文字は title に含めない。途中で切れていれば見えている分だけにし、推測で補わない。',
    '- 読み取りに自信がない予定は confidence を 0.5 以下にする。',
    '- 予定がない日や、カレンダー以外の部分（ブラウザ、タスクバー、広告）は無視する。'
  ].join('\n');
}

export function requestBody({ imageBase64, mimeType, today }) {
  return {
    contents: [{
      role: 'user',
      parts: [
        { text: prompt(today) },
        { inlineData: { mimeType, data: imageBase64 } }
      ]
    }],
    generationConfig: {
      responseMimeType: 'application/json',
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0
    }
  };
}

/** Returns `{ events: [...] }` or throws an Error with `status`. */
export async function readCalendarImage({ fetchImpl, apiKey, model, imageBase64, mimeType, today }) {
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
  const response = await fetchImpl(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': apiKey },
    body: JSON.stringify(requestBody({ imageBase64, mimeType, today }))
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload?.error?.message ?? `Gemini returned ${response.status}`);
    error.status = 502;
    throw error;
  }
  const text = (payload?.candidates?.[0]?.content?.parts ?? []).map((part) => part.text ?? '').join('');
  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    const error = new Error('Gemini did not return JSON');
    error.status = 502;
    throw error;
  }
  return { events: Array.isArray(parsed?.events) ? parsed.events : [] };
}
