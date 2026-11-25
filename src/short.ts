/**
 * 短链接 — D1（真数据）+ KV（跳转缓存）混合版，Workers 专用。
 *
 * 根路径，不占 /s/ 前缀：k7s.top/aB3x
 * 能走根路径，是因为脚本和短码的格式天然不撞：
 *  - 脚本永远带后缀：/arch.sh、/index.ps1（router.ts 只认 .sh / .ps1）
 *  - 短码永远不带点：单段、3~32 位 [A-Za-z0-9_-]，默认随机 4 位
 * 所以先看“有没有点”：有点的走脚本路由，没点的、不是保留词的，
 * 就当短码查；查不到返回 404，不回 index.html（印在广告上的错链
 * 应该明确 404，而不是悄悄跳首页）。
 *
 * 保留词：所有脚本的文件名（不带后缀）+ index / api / s / admin 等，
 * 命中保留词直接走原来的脚本路由，不查短链。
 *
 * 有效期：D1 里 expires_at（unix 秒，NULL = 永久），KV 里用
 * expirationTtl 自动清缓存；过期返回 410，并顺手删掉 D1/KV 里的记录。
 * 随机码 4 位，字符集去掉 0/O、1/l/I，印出来、手动输入都不容易看错。
 * 创建要带 token（见 README）：不设 SHORT_TOKEN 时允许创建，
 * 设了就必须 Authorization: Bearer <token>，否则任何人都能往你域名挂链。
 */

export interface ShortEnv {
  DB?: D1Database;
  SHORT_CACHE?: KVNamespace;
  SHORT_TOKEN?: string;
}

const CODE_RE = /^[A-Za-z0-9_-]{3,32}$/;
// scripts/ 下的文件名（不带后缀）+ 路由保留词
const RESERVED = new Set([
  "arch", "frpc", "frps", "frps-oidc", "frps-unified", "index",
  "init-once", "install", "k8s", "main", "setup_sources", "uninstall", "update",
  "api", "s", "admin", "new", "links", "short", "go", "login", "static",
  "assets", "favicon", "robots", "health", "well-known",
]);

// 去掉 0/O、1/l/I 的 base57，4 位约 1050 万种组合，个人用够了
const ALPHABET = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789";

function randomCode(length = 4): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join("");
}

export function parseExpiresIn(input: unknown): number | null | undefined {
  // 返回：秒数 | null（永久）| undefined（不合法）
  if (input === undefined || input === null || input === "") return 30 * 86400; // 默认 30 天
  if (typeof input === "number") return input <= 0 ? null : Math.floor(input);
  if (typeof input !== "string") return undefined;
  const s = input.trim().toLowerCase();
  if (["permanent", "perm", "forever", "never", "0", "永久"].includes(s)) return null;
  const m = /^(\d+)(s|m|h|d|w|y)?$/.exec(s);
  if (!m) return undefined;
  const n = Number(m[1]);
  const unit = { s: 1, m: 60, h: 3600, d: 86400, w: 604800, y: 31536000 }[m[2] || "s"]!;
  return n * unit;
}

function isPrivateHost(hostname: string): boolean {
  if (hostname === "localhost" || hostname.endsWith(".local")) return true;
  const m = /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/.exec(hostname);
  if (!m) return false;
  const [a, b] = [Number(m[1]), Number(m[2])];
  return a === 10 || a === 127 || (a === 192 && b === 168) || (a === 172 && b >= 16 && b <= 31);
}

function validateTarget(raw: unknown, selfHost: string): { ok: true; url: string } | { ok: false; error: string } {
  if (typeof raw !== "string" || !raw) return { ok: false, error: "url is required" };
  let u: URL;
  try {
    u = new URL(raw);
  } catch {
    return { ok: false, error: "url is not a valid URL" };
  }
  if (u.protocol !== "http:" && u.protocol !== "https:") return { ok: false, error: "only http(s) URLs are allowed" };
  if (u.hostname === selfHost) return { ok: false, error: "cannot shorten a link to this domain itself" };
  if (isPrivateHost(u.hostname)) return { ok: false, error: "private/local URLs are not allowed" };
  if (raw.length > 2048) return { ok: false, error: "url is too long" };
  return { ok: true, url: u.toString() };
}

function json(data: unknown, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-cache" },
  });
}

function authed(request: Request, env: ShortEnv): boolean {
  if (!env.SHORT_TOKEN) return true; // 没配 token 时允许创建，README 里提醒尽快配
  const url = new URL(request.url);
  const bearer = request.headers.get("authorization") || "";
  return bearer === `Bearer ${env.SHORT_TOKEN}` || url.searchParams.get("token") === env.SHORT_TOKEN;
}

/** 从路径里取出短码：根路径 /xxxx，或兼容的 /s/xxxx；不符合返回 null（走原路由）。 */
export function extractCode(pathname: string): string | null {
  let seg = pathname;
  if (seg.startsWith("/s/")) seg = seg.slice(3);
  else if (seg.startsWith("/")) seg = seg.slice(1);
  else return null;
  if (!seg || seg.includes("/") || seg.includes(".") || !CODE_RE.test(seg)) return null;
  if (RESERVED.has(seg.toLowerCase())) return null;
  return seg;
}

interface LinkRow {
  target: string;
  expires_at: number | null;
}

async function lookup(
  code: string,
  env: ShortEnv,
): Promise<
  | { status: "hit"; target: string; expires_at: number | null }
  | { status: "miss" }
  | { status: "expired" }
  | { status: "unconfigured" }
> {
  if (!env.DB) return { status: "unconfigured" };
  const now = Math.floor(Date.now() / 1000);
  if (env.SHORT_CACHE) {
    const neg = await env.SHORT_CACHE.get(`NEG:${code}`);
    if (neg) return { status: "miss" };
    const cached = await env.SHORT_CACHE.get<{ target: string; expires_at: number | null }>(`L:${code}`, "json");
    if (cached) {
      if (cached.expires_at !== null && cached.expires_at <= now) return { status: "expired" };
      return { status: "hit", target: cached.target, expires_at: cached.expires_at };
    }
  }
  const row = await env.DB.prepare("SELECT target, expires_at FROM links WHERE code = ?")
    .bind(code)
    .first<LinkRow>();
  if (!row) {
    if (env.SHORT_CACHE) await env.SHORT_CACHE.put(`NEG:${code}`, "1", { expirationTtl: 60 });
    return { status: "miss" };
  }
  if (row.expires_at !== null && row.expires_at <= now) {
    // 过期：D1 里删掉，KV 缓存也清掉，下次不再命中
    await env.DB.prepare("DELETE FROM links WHERE code = ?").bind(code).run();
    if (env.SHORT_CACHE) await env.SHORT_CACHE.delete(`L:${code}`);
    return { status: "expired" };
  }
  if (env.SHORT_CACHE) {
    const ttl = row.expires_at !== null ? row.expires_at - now : undefined;
    await env.SHORT_CACHE.put(`L:${code}`, JSON.stringify(row), ttl && ttl > 60 ? { expirationTtl: ttl } : undefined);
  }
  return { status: "hit", target: row.target, expires_at: row.expires_at };
}

async function handleRedirect(request: Request, env: ShortEnv, ctx: ExecutionContext, code: string): Promise<Response> {
  const found = await lookup(code, env);
  if (found.status === "unconfigured") return new Response("Short links not configured", { status: 503 });
  if (found.status === "expired") {
    return new Response("Short link expired", { status: 410, headers: { "Cache-Control": "no-cache" } });
  }
  if (found.status === "miss") {
    // 短码格式对但查不到：明确 404，不回首页
    return new Response("Short link not found", { status: 404, headers: { "Cache-Control": "no-cache" } });
  }
  const now = Math.floor(Date.now() / 1000);
  if (found.expires_at !== null && found.expires_at <= now) {
    return new Response("Short link expired", { status: 410, headers: { "Cache-Control": "no-cache" } });
  }
  // 点击数异步写 D1，不阻塞跳转；KV 本身没有原子计数，别用 KV 记数
  if (env.DB) {
    ctx.waitUntil(
      env.DB.prepare("UPDATE links SET clicks = clicks + 1 WHERE code = ?").bind(code).run().catch(() => {}),
    );
  }
  return new Response(null, {
    status: 302,
    headers: { Location: found.target, "Cache-Control": "no-cache" },
  });
}

async function handleApi(request: Request, env: ShortEnv, ctx: ExecutionContext): Promise<Response | null> {
  const url = new URL(request.url);
  if (!url.pathname.startsWith("/api/links")) return null;
  if (!env.DB) return json({ error: "short links not configured: create the D1 database and KV namespace first (see README)" }, 503);
  if (!authed(request, env)) return json({ error: "unauthorized" }, 401);

  const codeInPath = url.pathname.slice("/api/links".length).replace(/^\/+/, "");
  if (request.method === "GET" && !codeInPath) {
    // 列表：GET /api/links?limit=50
    const limit = Math.min(Math.max(Number(url.searchParams.get("limit") || 50), 1), 100);
    const rows = await env.DB.prepare(
      "SELECT code, target, expires_at, clicks, created_at FROM links ORDER BY created_at DESC LIMIT ?",
    )
      .bind(limit)
      .all<{ code: string; target: string; expires_at: number | null; clicks: number; created_at: number }>();
    return json({ links: rows.results ?? [] });
  }
  if (request.method === "GET" && codeInPath) {
    const row = await env.DB.prepare("SELECT code, target, expires_at, clicks, created_at FROM links WHERE code = ?")
      .bind(codeInPath)
      .first<{ code: string; target: string; expires_at: number | null; clicks: number; created_at: number }>();
    if (!row) return json({ error: "not found" }, 404);
    return json({ ...row, short: `${url.origin}/${row.code}` });
  }
  if (request.method === "DELETE" && codeInPath) {
    await env.DB.prepare("DELETE FROM links WHERE code = ?").bind(codeInPath).run();
    if (env.SHORT_CACHE) {
      await env.SHORT_CACHE.delete(`L:${codeInPath}`);
      await env.SHORT_CACHE.put(`NEG:${codeInPath}`, "1", { expirationTtl: 60 });
    }
    return json({ deleted: codeInPath });
  }
  if (request.method !== "POST" || codeInPath) return json({ error: "method not allowed" }, 405);

  let body: Record<string, unknown>;
  try {
    body = (await request.json()) as Record<string, unknown>;
  } catch {
    return json({ error: "invalid JSON" }, 400);
  }
  const target = validateTarget(body.url ?? body.target, url.hostname);
  if (!target.ok) return json({ error: target.error }, 400);
  const expiresIn = parseExpiresIn(body.expires_in ?? body.expiresIn);
  if (expiresIn === undefined) return json({ error: "expires_in is invalid, e.g. 1h, 7d, 30d, permanent" }, 400);
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = expiresIn === null ? null : now + expiresIn;

  let code = typeof body.slug === "string" && body.slug ? body.slug : typeof body.code === "string" && body.code ? body.code : "";
  if (code) {
    if (!CODE_RE.test(code) || RESERVED.has(code.toLowerCase())) {
      return json({ error: "slug must be 3-32 chars [A-Za-z0-9_-] and not a reserved word" }, 400);
    }
    const exists = await env.DB.prepare("SELECT 1 FROM links WHERE code = ?").bind(code).first();
    if (exists) return json({ error: "slug already taken" }, 409);
  } else {
    // 随机 4 位，撞了就换，最多试 10 次
    for (let i = 0; i < 10; i++) {
      const candidate = randomCode(4);
      const exists = await env.DB.prepare("SELECT 1 FROM links WHERE code = ?").bind(candidate).first();
      if (!exists) {
        code = candidate;
        break;
      }
    }
    if (!code) return json({ error: "could not allocate a code, try again" }, 503);
  }

  await env.DB.prepare("INSERT INTO links (code, target, expires_at, created_at, clicks) VALUES (?, ?, ?, ?, 0)")
    .bind(code, target.url, expiresAt, now)
    .run();
  if (env.SHORT_CACHE) {
    const ttl = expiresAt !== null ? expiresAt - now : undefined;
    await env.SHORT_CACHE.put(
      `L:${code}`,
      JSON.stringify({ target: target.url, expires_at: expiresAt }),
      ttl && ttl > 60 ? { expirationTtl: ttl } : undefined,
    );
    await env.SHORT_CACHE.delete(`NEG:${code}`);
  }
  return json({ code, short: `${url.origin}/${code}`, target: target.url, expires_at: expiresAt }, 201);
}

/**
 * 短链接前置处理。返回 Response 表示已处理（跳转 / API / 404 / 410），
 * 返回 null 表示不是短链接，走原来的脚本路由。
 * 只处理 GET/HEAD 的跳转和 /api/links；其他方法/路径一律放行。
 */
export async function tryShortLink(request: Request, env: ShortEnv, ctx: ExecutionContext): Promise<Response | null> {
  const url = new URL(request.url);
  if (url.pathname.startsWith("/api/links")) return handleApi(request, env, ctx);
  if (request.method !== "GET" && request.method !== "HEAD") return null;
  const code = extractCode(url.pathname);
  if (!code) return null;
  return handleRedirect(request, env, ctx, code);
}
