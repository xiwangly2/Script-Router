/**
 * Cloudflare Pages Functions 入口（catch-all）。
 * 选仓库即用：Pages Dashboard 选这个仓库，
 * Build command 填 `npm run build`，Output directory 填 `dist`，
 * functions/ 会自动被识别，不用额外配置。
 */
import { handleRequest } from "../src/router";

interface Env {
  ASSETS: Fetcher;
}

export const onRequest: PagesFunction<Env> = async ({ request, env }) => {
  const url = new URL(request.url);
  const getContent = async (path: string): Promise<string | null> => {
    const res = await env.ASSETS.fetch(new URL(`/${path}`, url.origin));
    if (!res.ok) return null;
    return await res.text();
  };
  return handleRequest(request, getContent);
};
