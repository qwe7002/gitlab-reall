/**
 * Reall Push Worker
 * -----------------
 * Bridges GitLab webhooks to Apple Push Notification service (APNs) so the
 * Reall iOS app can deliver CI/pipeline, merge request, and mention
 * notifications natively — letting users turn off GitLab email.
 *
 * Endpoints:
 *   POST /register    { deviceToken, platform, gitlabHost, gitlabUserId, gitlabUsername }
 *   POST /unregister  { deviceToken }
 *   POST /webhook     GitLab webhook payload (header: X-Gitlab-Token)
 *   GET  /health
 *
 * Bindings (see wrangler.toml):
 *   DEVICES               KV namespace
 * Secrets (wrangler secret put ...):
 *   APNS_AUTH_KEY         contents of the AuthKey_XXXX.p8 file
 *   APNS_KEY_ID           the 10-char key id
 *   APNS_TEAM_ID          your Apple Developer team id
 *   APNS_TOPIC            the app bundle id, e.g. com.qwe7002.reall
 *   APNS_PRODUCTION       "true" to use the production APNs host
 *   GITLAB_WEBHOOK_SECRET shared secret configured on the GitLab webhook
 */

export interface Env {
  DEVICES: KVNamespace;
  APNS_AUTH_KEY: string;
  APNS_KEY_ID: string;
  APNS_TEAM_ID: string;
  APNS_TOPIC: string;
  APNS_PRODUCTION?: string;
  GITLAB_WEBHOOK_SECRET: string;
}

interface DeviceRecord {
  deviceToken: string;
  platform: string;
  gitlabHost: string;
  gitlabUserId: number;
  gitlabUsername: string;
}

interface PushMessage {
  title: string;
  body: string;
  threadId?: string;
  url?: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);
    try {
      switch (`${request.method} ${url.pathname}`) {
        case 'GET /health':
          return json({ ok: true });
        case 'POST /register':
          return await handleRegister(request, env);
        case 'POST /unregister':
          return await handleUnregister(request, env);
        case 'POST /webhook':
          return await handleWebhook(request, env, ctx);
        default:
          return json({ error: 'Not found' }, 404);
      }
    } catch (err) {
      return json({ error: (err as Error).message }, 500);
    }
  },
};

// MARK: - Registration

function userKey(host: string, userId: number): string {
  return `user:${normalizeHost(host)}:${userId}`;
}

function normalizeHost(host: string): string {
  return host.replace(/\/+$/, '').toLowerCase();
}

async function handleRegister(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as Partial<DeviceRecord>;
  if (!body.deviceToken || !body.gitlabHost || body.gitlabUserId == null) {
    return json({ error: 'Missing fields' }, 400);
  }
  const record: DeviceRecord = {
    deviceToken: body.deviceToken,
    platform: body.platform ?? 'ios',
    gitlabHost: body.gitlabHost,
    gitlabUserId: body.gitlabUserId,
    gitlabUsername: body.gitlabUsername ?? '',
  };

  await env.DEVICES.put(`device:${record.deviceToken}`, JSON.stringify(record));

  // Maintain a set of tokens per (host, user).
  const key = userKey(record.gitlabHost, record.gitlabUserId);
  const existing = new Set<string>(JSON.parse((await env.DEVICES.get(key)) ?? '[]'));
  existing.add(record.deviceToken);
  await env.DEVICES.put(key, JSON.stringify([...existing]));

  return json({ ok: true });
}

async function handleUnregister(request: Request, env: Env): Promise<Response> {
  const body = (await request.json()) as { deviceToken?: string };
  if (!body.deviceToken) return json({ error: 'Missing deviceToken' }, 400);

  const raw = await env.DEVICES.get(`device:${body.deviceToken}`);
  if (raw) {
    const record = JSON.parse(raw) as DeviceRecord;
    const key = userKey(record.gitlabHost, record.gitlabUserId);
    const tokens = new Set<string>(JSON.parse((await env.DEVICES.get(key)) ?? '[]'));
    tokens.delete(body.deviceToken);
    await env.DEVICES.put(key, JSON.stringify([...tokens]));
  }
  await env.DEVICES.delete(`device:${body.deviceToken}`);
  return json({ ok: true });
}

// MARK: - Webhook handling

async function handleWebhook(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
  const token = request.headers.get('X-Gitlab-Token');
  if (!env.GITLAB_WEBHOOK_SECRET || token !== env.GITLAB_WEBHOOK_SECRET) {
    return json({ error: 'Invalid webhook token' }, 401);
  }

  const payload = (await request.json()) as any;
  const host = inferHost(payload);
  const routed = routeEvent(payload, host);
  if (!routed) return json({ ok: true, skipped: true });

  // Fan out asynchronously so GitLab gets a fast 200.
  ctx.waitUntil(deliver(env, host, routed.userIds, routed.message));
  return json({ ok: true });
}

interface RoutedEvent {
  userIds: number[];
  message: PushMessage;
}

function inferHost(payload: any): string {
  const url: string | undefined =
    payload?.project?.web_url ||
    payload?.repository?.homepage ||
    payload?.object_attributes?.url;
  if (url) {
    try {
      return new URL(url).origin;
    } catch {
      /* fall through */
    }
  }
  return 'https://gitlab.com';
}

/**
 * Translate a GitLab webhook into recipients + a notification.
 * Recipients are GitLab user ids that should be notified.
 */
function routeEvent(payload: any, host: string): RoutedEvent | null {
  const kind: string = payload.object_kind ?? payload.event_type ?? '';
  const projectName: string = payload?.project?.path_with_namespace ?? payload?.project?.name ?? 'project';

  switch (kind) {
    case 'pipeline': {
      const attrs = payload.object_attributes ?? {};
      const status: string = attrs.status;
      // Only the meaningful terminal states are worth a push.
      if (!['failed', 'success', 'canceled'].includes(status)) return null;
      const ref: string = attrs.ref ?? '';
      const userId: number | undefined = payload?.user?.id;
      if (userId == null) return null;
      const emoji = status === 'success' ? '✅' : status === 'failed' ? '❌' : '⚪️';
      return {
        userIds: [userId],
        message: {
          title: `${emoji} Pipeline ${status} · ${projectName}`,
          body: `Pipeline #${attrs.id} on ${ref}`,
          threadId: `pipeline-${attrs.id}`,
          url: `${host}/${payload?.project?.path_with_namespace}/-/pipelines/${attrs.id}`,
        },
      };
    }
    case 'build':
    case 'job': {
      const status: string = payload.build_status ?? payload.status;
      if (status !== 'failed') return null;
      const userId: number | undefined = payload?.user?.id;
      if (userId == null) return null;
      return {
        userIds: [userId],
        message: {
          title: `❌ Job failed · ${projectName}`,
          body: `${payload.build_name ?? 'Job'} on ${payload.ref ?? ''}`,
          threadId: `job-${payload.build_id}`,
        },
      };
    }
    case 'merge_request': {
      const attrs = payload.object_attributes ?? {};
      const action: string = attrs.action ?? '';
      const assignees: any[] = payload.assignees ?? [];
      const reviewers: any[] = payload.reviewers ?? [];
      const recipients = new Set<number>();
      if (['open', 'reopen', 'update'].includes(action)) {
        assignees.forEach((a) => recipients.add(a.id));
        reviewers.forEach((r) => recipients.add(r.id));
      } else if (action === 'merge' || action === 'close') {
        if (attrs.author_id) recipients.add(attrs.author_id);
      }
      if (recipients.size === 0) return null;
      return {
        userIds: [...recipients],
        message: {
          title: `MR ${action} · ${projectName}`,
          body: attrs.title ?? 'Merge request updated',
          threadId: `mr-${attrs.iid}`,
          url: attrs.url,
        },
      };
    }
    case 'note': {
      const attrs = payload.object_attributes ?? {};
      const author: string = payload?.user?.name ?? 'Someone';
      // Notify the noteable's author when someone comments.
      const target =
        payload?.merge_request?.author_id ?? payload?.issue?.author_id;
      if (target == null) return null;
      return {
        userIds: [target],
        message: {
          title: `💬 ${author} commented · ${projectName}`,
          body: (attrs.note ?? '').slice(0, 160),
          threadId: `note-${attrs.id}`,
          url: attrs.url,
        },
      };
    }
    case 'issue': {
      const attrs = payload.object_attributes ?? {};
      const assignees: any[] = payload.assignees ?? [];
      if (assignees.length === 0) return null;
      return {
        userIds: assignees.map((a) => a.id),
        message: {
          title: `Issue ${attrs.action ?? 'updated'} · ${projectName}`,
          body: attrs.title ?? 'Issue updated',
          threadId: `issue-${attrs.iid}`,
          url: attrs.url,
        },
      };
    }
    default:
      return null;
  }
}

// MARK: - Delivery

async function deliver(env: Env, host: string, userIds: number[], message: PushMessage): Promise<void> {
  const tokenSet = new Set<string>();
  for (const userId of userIds) {
    const list = JSON.parse((await env.DEVICES.get(userKey(host, userId))) ?? '[]') as string[];
    list.forEach((t) => tokenSet.add(t));
  }
  if (tokenSet.size === 0) return;

  const jwt = await apnsAuthToken(env);
  await Promise.all([...tokenSet].map((token) => sendAPNs(env, jwt, token, message)));
}

async function sendAPNs(env: Env, jwt: string, deviceToken: string, message: PushMessage): Promise<void> {
  const host = env.APNS_PRODUCTION === 'true' ? 'api.push.apple.com' : 'api.sandbox.push.apple.com';
  const payload = {
    aps: {
      alert: { title: message.title, body: message.body },
      sound: 'default',
      'thread-id': message.threadId,
    },
    url: message.url,
  };
  const res = await fetch(`https://${host}/3/device/${deviceToken}`, {
    method: 'POST',
    headers: {
      authorization: `bearer ${jwt}`,
      'apns-topic': env.APNS_TOPIC,
      'apns-push-type': 'alert',
      'apns-priority': '10',
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });
  if (res.status === 410 || res.status === 400) {
    // Token is no longer valid — clean it up.
    await env.DEVICES.delete(`device:${deviceToken}`);
  }
}

// MARK: - APNs JWT (ES256), cached ~50 minutes

let cachedToken: { value: string; issuedAt: number } | null = null;

async function apnsAuthToken(env: Env): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedToken && now - cachedToken.issuedAt < 3000) {
    return cachedToken.value;
  }
  const header = { alg: 'ES256', kid: env.APNS_KEY_ID };
  const claims = { iss: env.APNS_TEAM_ID, iat: now };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(claims))}`;

  const key = await importPKCS8(env.APNS_AUTH_KEY);
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput)
  );
  const token = `${signingInput}.${b64urlBytes(new Uint8Array(signature))}`;
  cachedToken = { value: token, issuedAt: now };
  return token;
}

async function importPKCS8(pem: string): Promise<CryptoKey> {
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\s+/g, '');
  const der = Uint8Array.from(atob(body), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );
}

// MARK: - Helpers

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'content-type': 'application/json' },
  });
}

function b64url(input: string): string {
  return b64urlBytes(new TextEncoder().encode(input));
}

function b64urlBytes(bytes: Uint8Array): string {
  let binary = '';
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}
