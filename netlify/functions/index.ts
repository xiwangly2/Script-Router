/**
 * Netlify Functions v2 入口。
 * 选仓库即用：Netlify 选这个仓库，netlify.toml 已配好 build / publish / functions，
 * 构建时 tools/build-assets.mjs 会生成 src/generated-assets.ts，再由这里嵌入。
 * path: "/*" 让它接管所有请求，路由逻辑在 src/router.ts 里。
 */
import { handleRequest } from "../../src/router";
import { FILES } from "../../src/generated-assets";

export default async (request: Request): Promise<Response> => {
  return handleRequest(request, async (path) => FILES[path] ?? null);
};

export const config = { path: "/*" };
