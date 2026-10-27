// supabase/functions/drive-proxy/index.ts
// ─────────────────────────────────────────────────────────────────────────────
// Supabase Edge Function: drive-proxy
//
// Problem: drive.google.com sends no `Access-Control-Allow-Origin` header,
// so any browser-side fetch to a "uc?export=download" link is blocked by
// CORS. This breaks the Ekklisia web build (Flutter Web) wherever an admin
// pasted a Google Drive share link instead of uploading a file directly
// (books > 10 MB, agbeya/pdf-content/saints PDFs) — CachedNetworkImage and
// flutter_cache_manager both perform a real fetch() to read the bytes, which
// the browser refuses without CORS headers. Native Android/iOS builds are
// unaffected (no browser, no CORS).
//
// Fix: this function fetches the Drive file server-side (server-to-server
// requests are never subject to CORS) and streams it back to the browser
// with `Access-Control-Allow-Origin: *` set — a transparent proxy, nothing
// is re-hosted or duplicated. Admins keep pasting Drive share links exactly
// as before; only the URL the *app* requests changes (see
// lib/admin/utils/drive_link_utils.dart → resolveDriveUrl()).
//
// Handles Google's "can't scan this file for viruses" interstitial page,
// which Drive returns instead of the actual bytes for files it doesn't
// virus-scan (large files, some archive/executable types) — we detect the
// HTML response, pull the `confirm` token back out of it, and re-request
// with that token + the warning cookie attached.
//
// ── Usage ─────────────────────────────────────────────────────────────────
//   GET /functions/v1/drive-proxy?id=<GOOGLE_DRIVE_FILE_ID>
//
// Only a bare file ID is accepted (validated below) — never a full URL —
// so this can't be abused as an open proxy for arbitrary sites.
//
// ── Deploy ────────────────────────────────────────────────────────────────
//   supabase functions deploy drive-proxy --no-verify-jwt
//
// No environment secrets required — this only relays files that are already
// public ("Anyone with the link") on Drive.
// ─────────────────────────────────────────────────────────────────────────────
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';

// ── CORS ──────────────────────────────────────────────────────────────────────

const corsHeaders = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, range',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
};

const errorResponse = (message: string, status: number) =>
  new Response(JSON.stringify({ error: message }), {
    status,
    headers: { 'Content-Type': 'application/json', ...corsHeaders },
  });

// ── Helpers ───────────────────────────────────────────────────────────────────

// Google Drive file IDs are alphanumeric plus '-' and '_', typically
// 25-45 chars. Widened a little either side to be safe; this is a
// whitelist, not a length check, so it costs nothing to be generous.
const DRIVE_ID_RE = /^[a-zA-Z0-9_-]{10,100}$/;

function driveDownloadUrl(id: string): string {
  return `https://drive.google.com/uc?export=download&id=${id}`;
}

/**
 * Pulls a `confirm=` token out of Google's "can't scan this file for
 * viruses" interstitial HTML. Google has used a couple of formats over the
 * years, so this tries a few patterns in order.
 */
function extractConfirmToken(html: string): string | null {
  const patterns = [
    /confirm=([0-9A-Za-z_-]+)&amp;id=/,
    /confirm=([0-9A-Za-z_-]+)&id=/,
    /name="confirm"\s+value="([0-9A-Za-z_-]+)"/,
  ];
  for (const re of patterns) {
    const m = html.match(re);
    if (m) return m[1];
  }
  return null;
}

/** First cookie value whose name starts with "download_warning" (Drive sets one per file on the interstitial). */
function extractWarningCookie(setCookieHeaders: string[]): string | null {
  for (const raw of setCookieHeaders) {
    const [pair] = raw.split(';');
    if (pair?.trim().startsWith('download_warning')) return pair.trim();
  }
  return null;
}

interface UpstreamResult {
  body: ReadableStream<Uint8Array> | null;
  contentType: string;
  contentLength: string | null;
}

async function fetchDriveFile(id: string): Promise<UpstreamResult> {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25_000);

  try {
    let res = await fetch(driveDownloadUrl(id), { signal: controller.signal });
    let contentType = res.headers.get('content-type') ?? 'application/octet-stream';

    // Large / unscannable files: Drive serves an HTML confirmation page
    // instead of the file on the first request.
    if (contentType.includes('text/html')) {
      const html = await res.text();
      const token = extractConfirmToken(html);

      if (token) {
        const cookie = extractWarningCookie(res.headers.get('set-cookie')?.split(', ') ?? []);
        const retryUrl = `${driveDownloadUrl(id)}&confirm=${token}`;
        res = await fetch(retryUrl, {
          signal: controller.signal,
          headers: cookie ? { cookie } : undefined,
        });
        contentType = res.headers.get('content-type') ?? 'application/octet-stream';
      }

      // Still HTML after the retry (or no token found) → this isn't a real
      // file response (bad ID, file not public, Drive changed their page
      // format again). Surface it as a failure rather than serving HTML
      // back to a PDF/image widget.
      if (contentType.includes('text/html')) {
        throw new Error('Drive returned an interstitial page with no usable confirm token');
      }
    }

    if (!res.ok) {
      throw new Error(`Drive responded ${res.status}`);
    }

    return {
      body: res.body,
      contentType,
      contentLength: res.headers.get('content-length'),
    };
  } finally {
    clearTimeout(timeout);
  }
}

// ── Handler ───────────────────────────────────────────────────────────────────

serve(async (req: Request): Promise<Response> => {
  if (req.method === 'OPTIONS') return new Response(null, { headers: corsHeaders });
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    return errorResponse('Method not allowed', 405);
  }

  const url = new URL(req.url);
  const id  = url.searchParams.get('id');

  if (!id || !DRIVE_ID_RE.test(id)) {
    return errorResponse('Missing or invalid "id" query parameter', 400);
  }

  try {
    const upstream = await fetchDriveFile(id);

    return new Response(req.method === 'HEAD' ? null : upstream.body, {
      status: 200,
      headers: {
        'Content-Type':   upstream.contentType,
        ...(upstream.contentLength ? { 'Content-Length': upstream.contentLength } : {}),
        'Cache-Control':  'public, max-age=86400',
        ...corsHeaders,
      },
    });
  } catch (err) {
    console.error(`[drive-proxy] id=${id} error:`, err);
    return errorResponse((err as Error).message, 502);
  }
});
