-- 短链接：D1 真数据表。KV 只做跳转缓存，不在这里建表。
-- 执行：npx wrangler d1 execute script-router-links --file migrations/0001_create_links.sql
-- （本地：npx wrangler d1 execute script-router-links --local --file migrations/0001_create_links.sql）
CREATE TABLE IF NOT EXISTS links (
  code TEXT PRIMARY KEY,          -- 短码，根路径 /xxxx，默认随机 4 位，不带点
  target TEXT NOT NULL,           -- 目标网址，只允许 http(s)
  expires_at INTEGER,             -- unix 秒，NULL = 永久
  clicks INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_links_expires_at ON links (expires_at);
