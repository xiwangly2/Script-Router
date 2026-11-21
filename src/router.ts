/**
 * Script-Router 共享路由 — 与平台无关。
 * 原 main.go handleRequest / getRequestSource / scriptTarget 的等价翻译。
 *
 * 各平台入口只负责提供 getContent()，路由本身不碰任何平台 API：
 *  - Workers / Pages：getContent 用 env.ASSETS.fetch() 实现
 *  - Vercel Edge / Netlify：getContent 查 tools/build-assets.mjs 生成的
 *    src/generated-assets.ts（构建时从 index.html + scripts/ 生成）
 *  - Go 版 main.go：不走这里，继续用原来的 os.ReadFile，行为不变
 *
 * getContent(path) 的 path 是 "index.html" 或 "scripts/arch.sh" 这类相对路径。
 */
export type Source = "shell" | "powershell" | "browser";
export type GetContent = (path: string) => Promise<string | null>;

const SHELL_UAS = [
  "curl", "wget", "aria2", "httpie", "python-requests", "python-urllib",
  "go-http-client", "libcurl", "node-fetch", "undici", "deno", "bun",
];
const POWERSHELL_UAS = ["windowspowershell", "powershell", "pwsh", "microsoft.powershell"];
const BROWSER_UAS = ["mozilla", "chrome", "safari", "firefox", "edg", "opr", "opera", "brave"];

export function getSource(request: Request): Source {
  const url = new URL(request.url);
  const format = (url.searchParams.get("format") || "").toLowerCase();
  const os = (url.searchParams.get("os") || "").toLowerCase();
  if (format === "ps1" || os === "windows" || os === "win32") return "powershell";
  if (format === "sh" || format === "bash" || os === "linux" || os === "darwin") return "shell";
  if (format === "html" || format === "browser") return "browser";

  const ua = (request.headers.get("user-agent") || "").toLowerCase();
  if (!ua) return "shell"; // 没 UA 的命令行工具默认按 shell 走
  if (POWERSHELL_UAS.some((k) => ua.includes(k))) return "powershell";
  if (BROWSER_UAS.some((k) => ua.includes(k))) return "browser";
  if (SHELL_UAS.some((k) => ua.includes(k))) return "shell";
  return "shell"; // 兜底：不是浏览器就按 shell，适用于各种工具
}

function isSafeName(name: string, ext: ".sh" | ".ps1"): boolean {
  if (!name || name.includes("/") || name.includes("\\") || name.includes("..")) return false;
  if (name.startsWith(".")) return false;
  if (!/^[A-Za-z0-9._-]+$/.test(name)) return false;
  return name.endsWith(ext);
}

export async function handleRequest(request: Request, getContent: GetContent): Promise<Response> {
  if (request.method !== "GET" && request.method !== "HEAD") {
    return new Response("Method Not Allowed", { status: 405 });
  }
  const isHead = request.method === "HEAD";
  const url = new URL(request.url);
  const source = getSource(request);

  // 浏览器：原逻辑是任意路径都返回 index.html，保留这一点。
  if (source === "browser") {
    const html = await getContent("index.html");
    if (html === null) return new Response("Internal Server Error", { status: 500 });
    return new Response(isHead ? null : html, {
      headers: {
        "Content-Type": "text/html; charset=utf-8",
        "Cache-Control": "no-cache",
      },
    });
  }

  const ext = source === "powershell" ? ".ps1" : ".sh";
  const indexFile = source === "powershell" ? "index.ps1" : "index.sh";
  const rawName =
    url.searchParams.get("file") ||
    (url.pathname === "/" || url.pathname === "" ? indexFile : decodeURIComponent(url.pathname.slice(1)));

  if (!isSafeName(rawName, ext)) {
    return new Response("File Not Found", { status: 404 });
  }

  const content = await getContent(`scripts/${rawName}`);
  if (content === null) return new Response("File Not Found", { status: 404 });

  const headers: Record<string, string> = {
    "Content-Type": source === "powershell" ? "text/plain" : "application/octet-stream",
    // 换源 / 快捷命令入口，更新要立即生效，不做长缓存。
    "Cache-Control": "no-cache",
  };
  if (source === "shell") headers["Content-Disposition"] = `attachment; filename="${rawName}"`;

  return new Response(isHead ? null : content, { status: 200, headers });
}
