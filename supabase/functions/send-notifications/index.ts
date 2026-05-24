// supabase/functions/send-notifications/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Supabase Edge Function: send-notifications
//
// Triggered by the Flutter admin client after a new book is published.
// Accepts a POST body with:
//   { title, body, tokens: string[], data: Record<string,string> }
//
// Sends a multicast Firebase Cloud Messaging push to all provided tokens.
//
// Deploy:
//   supabase functions deploy send-notifications --no-verify-jwt
//
// Environment secrets (set in Supabase dashboard → Project → Edge Functions):
//   FIREBASE_PROJECT_ID   — your Firebase project id
//   FIREBASE_SERVICE_ACCOUNT_JSON — full service account JSON (stringified)
// ─────────────────────────────────────────────────────────────────────────────
import { serve }       from 'https://deno.land/std@0.177.0/http/server.ts';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v2.8/mod.ts';

// ── Types ─────────────────────────────────────────────────────────────────────

interface NotificationPayload {
  title:  string;
  body:   string;
  tokens?: string[];
  topic?: string;
  data?:  Record<string, string>;
}

interface FcmMessage {
  message: {
    token:        string;
    notification: { title: string; body: string };
    data?:        Record<string, string>;
    android: {
      notification: {
        channel_id:   string;
        default_sound: boolean;
      };
    };
    apns: {
      payload: {
        aps: {
          alert: { title: string; body: string };
          sound: string;
          badge: number;
        };
      };
    };
  };
}

// ── Helper: Build JWT for Google OAuth2 ──────────────────────────────────────

async function buildGoogleJwt(serviceAccount: {
  client_email: string;
  private_key:  string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToArrayBuffer(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  return await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss:   serviceAccount.client_email,
      sub:   serviceAccount.client_email,
      aud:   'https://oauth2.googleapis.com/token',
      iat:   getNumericDate(0),
      exp:   getNumericDate(60 * 60), // 1 hour
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
    },
    key,
  );
}

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
  const jwt = await buildGoogleJwt(serviceAccount);

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion:  jwt,
    }),
  });

  const json = await res.json();
  if (!res.ok) throw new Error(`OAuth2 error: ${JSON.stringify(json)}`);
  return json.access_token as string;
}

// ── Main send function ────────────────────────────────────────────────────────

async function sendToToken(
  token:       string,
  title:       string,
  body:        string,
  data:        Record<string, string> | undefined,
  projectId:   string,
  accessToken: string,
): Promise<{ token: string; success: boolean; error?: string }> {
  const payload: FcmMessage = {
    message: {
      token,
      notification: { title, body },
      data,
      android: {
        notification: {
          channel_id:    'new_book_channel',

          default_sound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: 'default',
            badge: 1,
          },
        },
      },
    },
  };

  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method:  'POST',
    headers: {
      Authorization:  `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) return { token, success: true };

  const err = await res.json();
  return {
    token,
    success: false,
    error: err?.error?.message ?? 'Unknown FCM error',
  };
}

async function sendToTopic(
  topic:       string,
  title:       string,
  body:        string,
  data:        Record<string, string> | undefined,
  projectId:   string,
  accessToken: string,
): Promise<{ success: boolean; error?: string }> {
  const payload = {
    message: {
      topic,
      notification: { title, body },
      data,
      android: {
        notification: {
          channel_id:    'new_book_channel',

          default_sound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: 'default',
            badge: 1,
          },
        },
      },
    },
  };

  const url = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
  const res = await fetch(url, {
    method:  'POST',
    headers: {
      Authorization:  `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (res.ok) return { success: true };

  const err = await res.json();
  return {
    success: false,
    error: err?.error?.message ?? 'Unknown FCM error',
  };
}

// ── Edge Function Handler ─────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req: Request): Promise<Response> => {
  // CORS pre-flight
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders
    });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
    });
  }

  try {
    // ── Parse payload ──────────────────────────────────────────────────
    const payload = (await req.json()) as NotificationPayload;

    const tokens = payload.tokens ?? [];
    const hasTopic = typeof payload.topic === 'string' && payload.topic.trim().length > 0;

    if (!payload.title || !payload.body || (!tokens.length && !hasTopic)) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: title, body, tokens/topic' }),
        { status: 400 },
      );
    }

    // ── Load service account ───────────────────────────────────────────
    const projectId     = Deno.env.get('FIREBASE_PROJECT_ID') ?? '';
    const saRaw         = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON') ?? '{}';
    const serviceAccount = JSON.parse(saRaw);

    if (!projectId || !serviceAccount.client_email) {
      throw new Error('Missing FIREBASE_PROJECT_ID or FIREBASE_SERVICE_ACCOUNT_JSON env vars');
    }

    // ── Get OAuth2 access token ────────────────────────────────────────
    const accessToken = await getAccessToken(serviceAccount);

    if (hasTopic) {
      const result = await sendToTopic(
        payload.topic!.trim(),
        payload.title,
        payload.body,
        payload.data,
        projectId,
        accessToken,
      );

      if (!result.success) {
        return new Response(
          JSON.stringify({ success: false, error: result.error }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      return new Response(
        JSON.stringify({ success: true, topic: payload.topic, sent: 1 }),
        {
          status: 200,
          headers: {
            'Content-Type':                'application/json',
            ...corsHeaders
          },
        },
      );
    }

    // ── Fan-out to all tokens (parallel, max 500 per batch) ───────────
    const BATCH = 500;
    const results: { token: string; success: boolean; error?: string }[] = [];

    for (let i = 0; i < tokens.length; i += BATCH) {
      const batch = tokens.slice(i, i + BATCH);
      const batchResults = await Promise.all(
        batch.map((token) =>
          sendToToken(
            token,
            payload.title,
            payload.body,
            payload.data,
            projectId,
            accessToken,
          ),
        ),
      );
      results.push(...batchResults);
    }

    const successCount = results.filter((r) => r.success).length;
    const failureCount = results.length - successCount;

    console.log(
      `[send-notifications] Sent ${successCount}/${results.length} ` +
      `(${failureCount} failed)`,
    );

    return new Response(
      JSON.stringify({
        success:       true,
        total:         results.length,
        sent:          successCount,
        failed:        failureCount,
        failures:      results.filter((r) => !r.success),
      }),
      {
        status:  200,
        headers: {
          'Content-Type':                'application/json',
          ...corsHeaders
        },
      },
    );
  } catch (err) {
    console.error('[send-notifications] Error:', err);
    return new Response(
      JSON.stringify({ error: (err as Error).message }),
      {
        status:  500,
        headers: { 'Content-Type': 'application/json', ...corsHeaders },
      },
    );
  }
});
