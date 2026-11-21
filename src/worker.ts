/**
 * Cloudflare Workers 入口。
 * 选仓库即用：wrangler.toml 已配好 main / assets / run_worker_first，
 * 不需要构建步骤，assets 目录就是仓库根目录，index.html 和 scripts/ 本来就在那。
 */
import { handleRequest } from "./router";

interface Env {
  ASSETS: Fetcher;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const getContent = async (path: string): Promise<string | null> => {
      const res = await env.ASSETS.fetch(new URL(`/${path}`, url.origin));
      if (!res.ok) return null;
      return await res.text();
    };
    return handleRequest(request, getContent);
  },
} satisfies ExportedHandler<Env>;
