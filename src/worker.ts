/**
 * Cloudflare Workers 入口。
 * 选仓库即用：wrangler.toml 已配好 main / assets / run_worker_first，
 * [build] 先跑 npm run build 生成 dist/，再部署。
 * 短链接（D1+KV，根路径 /xxxx）在这里前置处理，没命中才走脚本路由。
 * 没配 D1/KV 时短链接返回 503，脚本路由不受影响。
 */
import { handleRequest } from "./router";
import { tryShortLink } from "./short";

interface Env {
  ASSETS: Fetcher;
  DB?: D1Database;
  SHORT_CACHE?: KVNamespace;
  SHORT_TOKEN?: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const short = await tryShortLink(request, env, ctx);
    if (short) return short;
    const url = new URL(request.url);
    const getContent = async (path: string): Promise<string | null> => {
      const res = await env.ASSETS.fetch(new URL(`/${path}`, url.origin));
      if (!res.ok) return null;
      return await res.text();
    };
    return handleRequest(request, getContent);
  },
} satisfies ExportedHandler<Env>;
