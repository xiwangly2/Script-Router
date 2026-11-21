/**
 * Vercel Edge Function 入口。
 * 选仓库即用：Vercel 选这个仓库，vercel.json 已配好 buildCommand 和 rewrites，
 * 构建时 tools/build-assets.mjs 会生成 src/generated-assets.ts，再由这里嵌入。
 * Edge Runtime 用 Web Request/Response，不用 Node 的 fs，见 Vercel 文档：
 * export const config = { runtime: 'edge' }，默认导出 handler(request: Request)。
 */
import { handleRequest } from "../src/router";
import { FILES } from "../src/generated-assets";

export const config = { runtime: "edge" };

export default async function handler(request: Request): Promise<Response> {
  return handleRequest(request, async (path) => FILES[path] ?? null);
}
