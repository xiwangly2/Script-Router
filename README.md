# Script-Router
一个用 Go 语言写的脚本路由器（例如快捷拉取执行自用脚本）

## 开箱即用（Serverless）

选仓库 / 填仓库 URL 就能部署，不用手动复制文件、不用改代码。
路由逻辑在 `src/router.ts`，各平台入口只是换一种读文件的方式，
Go 原服务（`main.go` + `Dockerfile`）完全不动，继续能用。

| 平台 | 怎么选 | 需要填的 |
|---|---|---|
| **Cloudflare Workers（主推）** | Workers → Create → 选这个仓库 | 什么都不用填，`wrangler.toml` 已配好 |
| **Cloudflare Pages** | Pages → Create → 选这个仓库 | Build command：`npm run build`；Output directory：`dist` |
| **Vercel** | Vercel → Add New Project → 选这个仓库 | 什么都不用填，`vercel.json` 已配好 |
| **Netlify** | Netlify → Add new site → 选这个仓库 | 什么都不用填，`netlify.toml` 已配好 |
| **Cloud Run / Docker** | 容器部署 | 原 `Dockerfile`，设 `PORT`，启动参数 `-addr 0.0.0.0:$PORT` |

本地 / 命令行部署：

```bash
npm install
npm run build        # 生成 dist/ + src/generated-assets.ts（Vercel/Netlify 用）
npx wrangler deploy  # Workers
npm run deploy:pages # Pages
```

自动部署：推到 `main` 就自动部署，见 `.github/workflows/deploy-workers.yml`
和 `deploy-pages.yml`，只需在仓库 Secrets 里配 `CLOUDFLARE_API_TOKEN`、
`CLOUDFLARE_ACCOUNT_ID`。

验证（部署后）：

```bash
curl -A "curl/8.0.1" https://k7s.top/ | head
curl -A "wget/1.21" https://k7s.top/arch.sh | head
curl -A "WindowsPowerShell/7.4" https://k7s.top/ | head
curl -A "Mozilla/5.0" https://k7s.top/ | head
```

## 短链接（Workers 专用，根路径）

`k7s.top/aB3x` 这种 4 位短链，印广告、贴海报、口头报都够短。
D1 是真数据（`code, target, expires_at, clicks`），KV 只做跳转缓存，
过期自动清。Pages / Vercel / Netlify 没有 D1/KV，所以短链接只在
Workers 上生效，其他平台还是只走脚本路由。

为什么根路径不跟脚本撞：脚本永远带后缀（`/arch.sh`、`/index.ps1`），
短码永远不带点（单段、3~32 位 `[A-Za-z0-9_-]`）。Worker 先看有没有点，
有点的走脚本，没点的、不是保留词（`arch`、`install`、`index`、`api` 等
脚本名）的就当短码查。查不到返回 404，不回首页；过期返回 410。
随机码默认 4 位，字符集去掉 `0/O、1/l/I`，手动输入不容易看错。

启用（只需一次，D1/KV 的 id 没法只靠选仓库自动出来）：

```bash
npx wrangler d1 create script-router-links
npx wrangler d1 execute script-router-links --file migrations/0001_create_links.sql
npx wrangler kv namespace create SHORT_CACHE
npx wrangler secret put SHORT_TOKEN   # 创建用的 token，不写进仓库
```

再把 `wrangler.toml` 里短链接那段取消注释、填上两个 id，部署一次。

用：

```bash
# 创建：默认 30 天，可改 1h / 7d / 30d / permanent，slug 可自定义
curl -X POST https://k7s.top/api/links \
  -H "Authorization: Bearer <SHORT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/活动页", "expires_in": "permanent"}'
# -> {"code": "aB3x", "short": "https://k7s.top/aB3x", ...}

curl -X POST https://k7s.top/api/links \
  -H "Authorization: Bearer <SHORT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com/限时", "slug": "sale", "expires_in": "7d"}'

# 访问：浏览器直接跳，curl 要加 -L 才跟随 302
curl -L https://k7s.top/aB3x
# 查 / 删 / 列表（都要 token）
curl -H "Authorization: Bearer <SHORT_TOKEN>" https://k7s.top/api/links/aB3x
curl -X DELETE -H "Authorization: Bearer <SHORT_TOKEN>" https://k7s.top/api/links/aB3x
curl -H "Authorization: Bearer <SHORT_TOKEN>" "https://k7s.top/api/links?limit=50"
```

目标只允许 `http(s)`，不允许指回本站、不允许内网地址；没配
`SHORT_TOKEN` 时创建接口是开放的，尽快配上，否则任何人都能往你
域名上挂链。

原理：构建时 `tools/build-assets.mjs`（零依赖）把 `index.html` +
`scripts/*.sh|*.ps1` 生成 `dist/` 和 `src/generated-assets.ts`。
Workers 的 `wrangler.toml` 里 `[build] command = "npm run build"` +
`[assets] directory = "./dist"` + `run_worker_first = true`；
`[assets]` 绝不能指向 `"./"`，否则 Wrangler 会把整个仓库（含
`node_modules/workerd`，155 MiB，超单文件 25 MiB 上限）都当成
assets 上传。Pages 的构建命令在 Dashboard 里填，不用写进
`wrangler.toml`（Pages 会拒绝 `[build]`）。


突然发现用 PHP 顺带路由一下也不错

这个项目是我突发奇想折腾出来的，当时玩的虚拟机实在太多了，一个一个的改东西太麻烦了，于是索性自己手搓了一个Shell

后来发现GitHub上已经有大佬写好现成的了……

不过练练手也不错

> [!NOTE]  
> 怀念`vs8.top`，这个域名被注册局暂停解析了，目前域名托管商也没办法申诉，原因是重定向滥用，所以暂时换成了`k7s.top`

## 开始

简短的一句话命令，如果系统上没有 bash 的话，可以使用 sh 或者 zsh 等等 shell 代替，使用 sh 执行可能有部分命令用不了
```bash
bash <(curl k7s.top)
```
或者使用 wget ：
```bash
bash <(wget -qO- k7s.top)
```

对于 sudo 提升的权限
```bash
sudo bash -c "$(curl -fsSL k7s.top)"
```

更通用的方法
```bash
curl -fsSL k7s.top -o main.sh
chmod +x main.sh
bash main.sh
```

## 功能
```bash
[root@localhost ~] bash <(curl -sL k7s.top)
请输入选项：
-1. 执行快捷菜单(一些实用功能)
1. 执行arch.sh脚本(查看架构)
2. 执行install.sh脚本(没写)
3. 执行update.sh脚本(没写)
4. 执行uninstall.sh脚本(没写)
5. 一键换清华源setup_sources.sh(支持多种发行版)
-1
请输入选项：
1. 一键关闭SELinux(redhat系Linux需要)
2. 一键允许root用户连接ssh
3. 一键设置vi-tiny可以使用插入(Debian最小化安装可能出现的问题)
1
/usr/sbin/setenforce: SELinux is disabled

[root@localhost ~] bash <(curl -sSL k7s.top)
请输入选项：
-1. 执行快捷菜单(一些实用功能)
1. 执行arch.sh脚本(查看架构)
2. 执行install.sh脚本(没写)
3. 执行update.sh脚本(没写)
4. 执行uninstall.sh脚本(没写)
5. 一键换清华源setup_sources.sh(支持多种发行版)
5
Supported Linux distributions:(Only the official original version is supported)
1. Ubuntu 22.04 LTS
2. Debian 12
3. CentOS 7
4. Fedora 30
5. OpenBSD
6. Alpine
7. Arch Linux
8. openSUSE Tumbleweed
9. openSUSE Leap 15.3
Enter your Linux distribution choice: 3
Setting up sources for CentOS 7...
已加载插件：fastestmirror
Determining fastest mirrors
base                                                                                                                                                 | 3.6 kB  00:00:00
extras                                                                                                                                               | 2.9 kB  00:00:00
updates                                                                                                                                              | 2.9 kB  00:00:00
(1/8): extras/7/x86_64/filelists_db                                                                                                                  | 303 kB  00:00:00
(2/8): extras/7/x86_64/primary_db                                                                                                                    | 250 kB  00:00:00
(3/8): extras/7/x86_64/other_db                                                                                                                      | 150 kB  00:00:00
(4/8): base/7/x86_64/other_db                                                                                                                        | 2.6 MB  00:00:01
(5/8): base/7/x86_64/filelists_db                                                                                                                    | 7.2 MB  00:00:01
(6/8): updates/7/x86_64/primary_db                                                                                                                   |  22 MB  00:00:03
(7/8): updates/7/x86_64/other_db                                                                                                                     | 1.4 MB  00:00:00
(8/8): updates/7/x86_64/filelists_db                                                                                                                 |  12 MB  00:00:04
元数据缓存已建立
Source setup completed.


```

### 一键安装 frp

frps
```bash
# token 配置
bash <(curl k7s.top/frps.sh)
# oidc 配置
# bash <(curl k7s.top/frps-oidc.sh)
# 统一配置（实验）
# bash <(curl k7s.top/frps-unified.sh) -y --auth token --mirror ghfast
# auth 可选 token oidc, mirror 可选 ghfast, github, gitee(暂未支持)
```

对于需要加速下载的情况可以替换链接为镜像地址，例如 `https://github.com/fatedier/frp/releases/download/` 替换为 `https://ghfast.top/https://github.com/fatedier/frp/releases/download/` 

frpc
```bash
bash <(curl k7s.top/frpc.sh)
```

卸载 frps
```bash
systemctl stop frps
systemctl disable frps
rm -rf /usr/local/bin/frps
rm -rf /etc/frp/frps.toml
```

卸载 frpc
```bash
systemctl stop frpc
systemctl disable frpc
rm -rf /usr/local/bin/frpc
rm -rf /etc/frp/frpc.toml
```

## 搭建

编译成二进制文件

```bash
go build -o script-router main.go
```

然后运行

```bash
./script-router

# 可以指定地址和端口
./script-router -addr 0.0.0.0:8080
```

可以根据需要配置反向代理

# 部署

使用 systemd 管理脚本路由器

```bash
cat >/etc/systemd/system/Script-Router.service <<EOF
[Unit]
Description=Script-Router service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/Script-Router -addr 0.0.0.0:28789
Restart=always
WorkingDirectory=/root/Script-Router/

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable Script-Router
systemctl start Script-Router
# 查看状态
systemctl status Script-Router
# 查看日志
journalctl -u Script-Router -f
# upload shell script to Workdirectory
curl http://localhost:28789
# 卸载
#systemctl stop Script-Router
#systemctl disable Script-Router
#rm -f /etc/systemd/system/Script-Router.service
```

使用 docker 部署

```bash
docker run -d --restart=always --name script-router -p 28789:8080 ghcr.io/xiwangly2/script-router:main
```

参考
- https://github.com/SuperManito/LinuxMirrors