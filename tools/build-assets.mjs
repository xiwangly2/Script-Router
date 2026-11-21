#!/usr/bin/env node
/**
 * 构建脚本（零依赖，只用 Node 内置 fs/path）。
 * 平台在部署时自动跑它，不需要使用者手动复制文件：
 *  - Vercel：vercel.json 的 buildCommand
 *  - Netlify：netlify.toml 的 build.command
 *  - Pages：Dashboard 的 Build command 填 `npm run build`
 *  - Workers：不需要它（assets 直接就是仓库根目录），但跑了也没坏处
 *  - GitHub Actions：deploy-*.yml 里跑 `npm run build`
 *
 * 做两件事，都从仓库根目录的 index.html + scripts/ 读，不改源文件：
 *  1. dist/index.html + dist/scripts/*.sh|*.ps1（给 Pages / Netlify 当静态输出）
 *  2. src/generated-assets.ts（给 Vercel Edge / Netlify Functions 嵌入用，
 *     用 JSON.stringify 转义，脚本里的 $()、反引号、${} 都安全）
 * 只收 .sh / .ps1，不收 .mjs / .md / 其他文件。
 */
import { cp, mkdir, readdir, readFile, rm, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const dist = path.join(root, "dist");
const files = { "index.html": await readFile(path.join(root, "index.html"), "utf8") };

await rm(dist, { recursive: true, force: true });
await mkdir(path.join(dist, "scripts"), { recursive: true });

for (const name of await readdir(path.join(root, "scripts"))) {
  if (!name.endsWith(".sh") && !name.endsWith(".ps1")) continue;
  const content = await readFile(path.join(root, "scripts", name), "utf8");
  files[`scripts/${name}`] = content;
}

await cp(path.join(root, "index.html"), path.join(dist, "index.html"));
await cp(path.join(root, "scripts"), path.join(dist, "scripts"), {
  recursive: true,
  filter: (src) => src.endsWith(".sh") || src.endsWith(".ps1") || src.endsWith("scripts"),
});

const generated = `// 由 tools/build-assets.mjs 生成，不要手改。
export const FILES: Record<string, string> = ${JSON.stringify(files, null, 2)};
`;
await writeFile(path.join(root, "src", "generated-assets.ts"), generated, "utf8");
console.log(`build-assets: ${Object.keys(files).length} files -> dist/ + src/generated-assets.ts`);
