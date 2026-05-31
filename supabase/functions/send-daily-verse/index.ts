// supabase/functions/send-daily-verse/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Supabase Edge Function: send-daily-verse
//
// Picks the next unsent verse from the `daily_verses` Firestore collection
// (lowest `order` where `sent_date` is empty and `is_active` is true),
// sends a push notification to the "daily_verse" FCM topic, then marks
// that verse's `sent_date` with today's date so it is never sent again.
//
// After all 200 verses have been sent the function returns a 200 with
// reason: "all_sent".  Reset individual verses from the admin dashboard
// (tap the ↺ icon) to reuse them.
//
// ── Schedule at 9AM local time ────────────────────────────────────────────────
// Run once in the Supabase SQL editor (adjust UTC offset for your timezone):
//
//   SELECT cron.schedule(
//     'daily-verse-notification',
//     '0 7 * * *',   -- 09:00 Cairo / Athens (UTC+2 winter, use 0 6 for UTC+3 summer)
//     $$
//       SELECT net.http_post(
//         url     := 'https://<PROJECT_REF>.supabase.co/functions/v1/send-daily-verse',
//         headers := '{"Content-Type":"application/json","Authorization":"Bearer <ANON_KEY>"}'::jsonb,
//         body    := '{}'::jsonb
//       )
//     $$
//   );
//
// ── Deploy ────────────────────────────────────────────────────────────────────
//   supabase functions deploy send-daily-verse --no-verify-jwt
//
// ── Environment secrets ───────────────────────────────────────────────────────
//   FIREBASE_PROJECT_ID           — Firebase project id
//   FIREBASE_SERVICE_ACCOUNT_JSON — full service account JSON (stringified)
// ─────────────────────────────────────────────────────────────────────────────
import { serve }       from 'https://deno.land/std@0.177.0/http/server.ts';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.8/mod.ts';

// ── Types ─────────────────────────────────────────────────────────────────────

interface VerseDoc {
  firestoreId: string;
  order:       number;
  verseAr:     string;
  referenceAr: string;
  verseEl:     string;
  referenceEl: string;
}

// ── JWT / OAuth2 helpers ──────────────────────────────────────────────────────

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const buf    = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) buf[i] = binary.charCodeAt(i);
  return buf.buffer;
}

async function getAccessToken(serviceAccount: {
  client_email: string;
  private_key:  string;
}): Promise<string> {
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const jwt = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss:   serviceAccount.client_email,
      sub:   serviceAccount.client_email,
      aud:   'https://oauth2.googleapis.com/token',
      iat:   getNumericDate(0),
      exp:   getNumericDate(3600),
      scope: [
        'https://www.googleapis.com/auth/firebase.messaging',
        'https://www.googleapis.com/auth/datastore',
      ].join(' '),
    },
    key,
  );

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method:  'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body:    new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion:  jwt,
    }),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(`OAuth2 error: ${JSON.stringify(json)}`);
  return json.access_token as string;
}

// ── Firestore helpers ─────────────────────────────────────────────────────────

const firestoreBase = (projectId: string) =>
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

/** Returns true if a verse with sent_date == today already exists. */
async function todayAlreadySent(
  projectId:   string,
  accessToken: string,
  today:       string,
): Promise<boolean> {
  const url = `${firestoreBase(projectId)}:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'daily_verses' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'sent_date' },
          op:    'EQUAL',
          value: { stringValue: today },
        },
      },
      limit: 1,
    },
  };

  const res  = await fetch(url, {
    method:  'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
  });
  const docs = await res.json() as Array<{ document?: unknown }>;
  return docs.some((d) => d.document !== undefined);
}

/**
 * Fetches the next unsent verse ordered by `order` ASC.
 * Returns null if all verses have been sent.
 */
async function fetchNextVerse(
  projectId:   string,
  accessToken: string,
): Promise<VerseDoc | null> {
  const url  = `${firestoreBase(projectId)}:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'daily_verses' }],
      where: {
        compositeFilter: {
          op: 'AND',
          filters: [
            {
              fieldFilter: {
                field: { fieldPath: 'sent_date' },
                op:    'EQUAL',
                value: { stringValue: '' },
              },
            },
            {
              fieldFilter: {
                field: { fieldPath: 'is_active' },
                op:    'EQUAL',
                value: { booleanValue: true },
              },
            },
          ],
        },
      },
      orderBy: [{ field: { fieldPath: 'order' }, direction: 'ASCENDING' }],
      limit: 1,
    },
  };

  const res  = await fetch(url, {
    method:  'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
  });
  const rows = await res.json() as Array<{ document?: { name: string; fields: Record<string, unknown> } }>;

  const row = rows.find((r) => r.document !== undefined);
  if (!row?.document) return null;

  const { name, fields } = row.document;
  const str  = (k: string) => (fields[k] as { stringValue?: string })?.stringValue  ?? '';
  const num  = (k: string) => (fields[k] as { integerValue?: string })?.integerValue
                           ?? (fields[k] as { doubleValue?: number })?.doubleValue
                           ?? 0;

  return {
    firestoreId: name.split('/').pop()!,
    order:       Number(num('order')),
    verseAr:     str('verse_ar'),
    referenceAr: str('reference_ar'),
    verseEl:     str('verse_el'),
    referenceEl: str('reference_el'),
  };
}

/**
 * Clears `sent_date` on every document in daily_verses so the cycle restarts.
 * Firestore REST doesn't support batch writes, so we run a runQuery to get all
 * doc names and PATCH each one sequentially (200 docs ≈ 200 small requests).
 */
async function resetAllSentDates(
  projectId:   string,
  accessToken: string,
): Promise<number> {
  // Fetch all doc names (we only need `name`, so select nothing to minimise payload)
  const url  = `${firestoreBase(projectId)}:runQuery`;
  const body = {
    structuredQuery: {
      from: [{ collectionId: 'daily_verses' }],
      // No where-clause — reset every document
    },
  };

  const res  = await fetch(url, {
    method:  'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify(body),
  });
  const rows = await res.json() as Array<{ document?: { name: string } }>;
  const docs = rows.filter((r) => r.document !== undefined).map((r) => r.document!.name);

  // PATCH each doc to clear sent_date
  await Promise.all(
    docs.map((name) =>
      fetch(`${name}?updateMask.fieldPaths=sent_date`, {
        method:  'PATCH',
        headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
        body:    JSON.stringify({ fields: { sent_date: { stringValue: '' } } }),
      }),
    ),
  );

  return docs.length;
}

/** Stamps `sent_date` on the verse document. */
async function markAsSent(
  projectId:   string,
  accessToken: string,
  docId:       string,
  date:        string,
): Promise<void> {
  const url = `${firestoreBase(projectId)}/daily_verses/${docId}` +
              `?updateMask.fieldPaths=sent_date`;

  const res = await fetch(url, {
    method:  'PATCH',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify({
      fields: { sent_date: { stringValue: date } },
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`Firestore PATCH failed: ${err}`);
  }
}

// ── FCM send ──────────────────────────────────────────────────────────────────

async function sendFcmNotification(
  verse:       VerseDoc,
  projectId:   string,
  accessToken: string,
): Promise<void> {
  const title  = 'آية اليوم • Ο Στίχος της Ημέρας';
  const bodyAr = verse.verseAr.length > 120
    ? `${verse.verseAr.substring(0, 117)}…`
    : verse.verseAr;

  const payload = {
    message: {
      topic: 'daily_verse',
      notification: { title, body: bodyAr },
      data: {
        type:        'daily_verse',
        verse_ar:    verse.verseAr,
        reference_ar: verse.referenceAr,
        verse_el:    verse.verseEl,
        reference_el: verse.referenceEl,
      },
      android: {
        notification: {
          channel_id:    'daily_verse_channel',
          default_sound: true,
          tag:           'daily_verse',
        },
        priority: 'high',
      },
      apns: {
        payload: {
          aps: {
            alert: { title, subtitle: verse.referenceAr, body: bodyAr },
            sound: 'default',
            badge: 1,
            'thread-id': 'daily_verse',
            'content-available': 1,
          },
        },
        headers: {
          'apns-priority':    '10',
          'apns-push-type':   'alert',
          'apns-collapse-id': 'daily_verse',
        },
      },
    },
  };

  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method:  'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body:    JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.json();
    throw new Error(`FCM error: ${err?.error?.message ?? JSON.stringify(err)}`);
  }
}

// ── CORS ──────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'POST')    return json({ error: 'Method not allowed' }, 405);

  try {
    const today = todayString();
    console.log(`[send-daily-verse] Running for ${today}`);

    // ── Credentials ────────────────────────────────────────────────────
    const projectId      = Deno.env.get('FIREBASE_PROJECT_ID') ?? '';
    const saRaw          = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '{}';
    const serviceAccount = JSON.parse(saRaw);

    if (!projectId || !serviceAccount.client_email) {
      throw new Error('Missing FIREBASE_PROJECT_ID or FIREBASE_SERVICE_ACCOUNT_JSON');
    }

    const accessToken = await getAccessToken(serviceAccount);

    // ── Guard: already sent today? ──────────────────────────────────────
    if (await todayAlreadySent(projectId, accessToken, today)) {
      console.log(`[send-daily-verse] Already sent today — skipping`);
      return json({ success: false, reason: 'already_sent_today', date: today });
    }

    // ── Pick next unsent verse (auto-reset cycle if exhausted) ─────────
    let verse = await fetchNextVerse(projectId, accessToken);
    let cycleReset = false;

    if (!verse) {
      console.log(`[send-daily-verse] All verses have been sent — resetting cycle`);
      const count = await resetAllSentDates(projectId, accessToken);
      console.log(`[send-daily-verse] Reset ${count} verses — restarting from #1`);
      cycleReset = true;
      verse = await fetchNextVerse(projectId, accessToken);
    }

    if (!verse) {
      // No active verses exist at all
      console.log(`[send-daily-verse] No active verses found after reset`);
      return json({ success: false, reason: 'no_active_verses', date: today });
    }

    console.log(`[send-daily-verse] Sending verse #${verse.order}: ${verse.referenceAr}`);

    // ── Send FCM notification ───────────────────────────────────────────
    await sendFcmNotification(verse, projectId, accessToken);

    // ── Mark as sent ────────────────────────────────────────────────────
    await markAsSent(projectId, accessToken, verse.firestoreId, today);

    console.log(`[send-daily-verse] ✓ Done — verse #${verse.order} marked sent on ${today}`);

    return json({
      success:     true,
      date:        today,
      order:       verse.order,
      referenceAr: verse.referenceAr,
      referenceEl: verse.referenceEl,
      cycleReset,
    });

  } catch (err) {
    console.error('[send-daily-verse] Error:', err);
    return json({ error: (err as Error).message }, 500);
  }
});

// ── Utilities ─────────────────────────────────────────────────────────────────

function todayString(): string {
  const d = new Date();
  return `${d.getUTCFullYear()}-${String(d.getUTCMonth() + 1).padStart(2, '0')}-${String(d.getUTCDate()).padStart(2, '0')}`;
}
