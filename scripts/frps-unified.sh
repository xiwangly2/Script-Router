#!/bin/bash
set -eu

# 设置 PATH 变量
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

yes_flag=""
# 参数解析
while [[ $# -gt 0 ]]; do
  case $1 in
    --auth)
      auth="$2"
      shift 2
      ;;
    --mirror)
      mirror="$2"
      shift 2
      ;;
    -y|--yes)
      yes_flag="y"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# 交互式选择
if [[ -z "$auth" ]]; then
  echo "请选择认证方式:"
  echo "1. token"
  echo "2. oidc"
  read -p "输入序号(1/2): " auth_sel
  case "$auth_sel" in
    1) auth="token" ;;
    2) auth="oidc" ;;
    *) echo "无效选项"; exit 1 ;;
  esac
fi
if [[ -z "$mirror" ]]; then
  echo "请选择下载源:"
  echo "1. 官方 github"
  echo "2. ghfast 镜像"
  echo "3. gitee"
  read -p "输入序号(1/2/3): " mirror_sel
  case "$mirror_sel" in
    1) mirror="official" ;;
    2) mirror="ghfast" ;;
    3) mirror="gitee" ;;
    *) echo "无效选项"; exit 1 ;;
  esac
fi

# 选择包管理器
if   command -v dnf      >/dev/null 2>&1; then INSTALL="dnf install --allowerasing -y"
elif command -v yum      >/dev/null 2>&1; then INSTALL="yum install -y"
elif command -v apt-get  >/dev/null 2>&1; then INSTALL="apt-get install -y"
elif command -v apk      >/dev/null 2>&1; then INSTALL="apk add --no-cache"
elif command -v zypper   >/dev/null 2>&1; then INSTALL="zypper install -y"
elif command -v pacman   >/dev/null 2>&1; then INSTALL="pacman -Sy --noconfirm"
else
  echo "Unsupported package manager"; exit 1
fi

# 按需检测并安装依赖
for pkg in curl tar; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    echo "Package '$pkg' not detected. Installing..."
    $INSTALL "$pkg"
  fi
done

# 检查 frps 是否已安装
if [ -f /usr/local/bin/frps ]; then
  echo "frps 已安装，执行更新..."
else
  echo "frps 未安装，执行安装..."
fi

# 获取最新版本号和下载地址
if [[ "$mirror" == "gitee" ]]; then
  LATEST_RELEASE=$(curl -s https://gitee.com/api/v5/repos/mvscode/frps-onekey/releases/latest | grep -oP '"tag_name":"\Kv[^"]+' | cut -c2-)
  VERSION_TAG="v${LATEST_RELEASE}"
  VERSION="${LATEST_RELEASE}"
else
  VERSION_TAG=$(curl -sI https://github.com/fatedier/frp/releases/latest | grep -i location | sed -E 's/.*\/tag\/(v[0-9.]+).*/\1/')
  VERSION=${VERSION_TAG#v}
fi

# 架构检测
ARCH_UNAME=$(uname -m)
case "$ARCH_UNAME" in
  x86_64)      ARCH=amd64 ;;
  i386|i486|i586|i686) ARCH=386 ;;
  aarch64)     ARCH=arm64 ;;
  armv7l)      ARCH=arm ;;
  mips)        ARCH=mips ;;
  mips64)      ARCH=mips64 ;;
  mipsel)      ARCH=mipsle ;;
  mips64el)    ARCH=mips64le ;;
  riscv64)     ARCH=riscv64 ;;
  *)           echo "Unsupported arch: $ARCH_UNAME"; exit 1 ;;
esac

# 下载源处理
if [[ "$mirror" == "ghfast" ]]; then
  BASE_URL="https://ghfast.top/https://github.com/fatedier/frp/releases/download/${VERSION_TAG}"
elif [[ "$mirror" == "gitee" ]]; then
  BASE_URL="https://gitee.com/lj47312/frp/releases/download/v${VERSION}"
else
  BASE_URL="https://github.com/fatedier/frp/releases/download/${VERSION_TAG}"
fi

# 下载解压
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
curl -sSL -o frp.tar.gz "${BASE_URL}/frp_${VERSION}_linux_${ARCH}.tar.gz"
tar -xzf frp.tar.gz

# 用户友好提示
INSTALL_PATH="/usr/local/bin/frps"
CONFIG_PATH="/etc/frp/frps.toml"
echo "\nfrps 安装位置: $INSTALL_PATH"
echo "frps 配置文件: $CONFIG_PATH"
echo "\n即将安装/更新 frps，是否继续？ [y/N]"
if [[ "$yes_flag" == "y" ]]; then
  confirm="y"
else
  read -r confirm
fi
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "已取消安装。"
  exit 0
fi

# 部署二进制与配置
mv -f "frp_${VERSION}_linux_${ARCH}/frps" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
mkdir -p /etc/frp
if [ ! -f "$CONFIG_PATH" ]; then
  if [[ "$auth" == "token" ]]; then
    cat >"$CONFIG_PATH" <<EOF
bindAddr = "0.0.0.0"
bindPort = 7000
kcpBindPort = 7000
quicBindPort = 7001

auth.method = "token"
auth.token = "xxx"

webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "xiwangly"
webServer.password = "xxx"
EOF
  else
    cat >"$CONFIG_PATH" <<EOF
bindAddr = "0.0.0.0"
bindPort = 7000
kcpBindPort = 7000
quicBindPort = 7001

auth.method = "oidc"
auth.oidc.issuer = "https://auth.xiwangly.com"
auth.oidc.audience = ""

#webServer.addr = "0.0.0.0"
#webServer.port = 7500
#webServer.user = "xiwangly"
#webServer.password = "xxx"

# tls
#transport.tls.force = true
#transport.tls.certFile = "/etc/frp/ssl/server.crt"
#transport.tls.keyFile = "/etc/frp/ssl/server.key"
#transport.tls.trustedCaFile = "/etc/frp/ssl/ca.crt"
EOF
  fi
else
  echo "$CONFIG_PATH 已存在，跳过生成。"
fi

# Init 系统检测
if [ -d /run/systemd/system ]; then
  cat >/etc/systemd/system/frps.service <<EOF
[Unit]
Description=frps service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frps -c /etc/frp/frps.toml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable frps
  systemctl start frps
elif command -v rc-service >/dev/null; then
  cat >/etc/init.d/frps <<'EOF'
#!/sbin/openrc-run
command="/usr/local/bin/frps"
command_args="-c /etc/frp/frps.toml"
pidfile="/var/run/frps.pid"
depend() {
  need net
}
EOF
  chmod +x /etc/init.d/frps
  rc-update add frps default
  rc-service frps start
elif [ -d /etc/init.d ]; then
  cat >/etc/init.d/frps <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          frps
# Required-Start:    $network
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: frp server daemon
### END INIT INFO

case "$1" in
  start)
    /usr/local/bin/frps -c /etc/frp/frps.toml &
    ;;
  stop)
    killall frps
    ;;
  status)
    pidof frps >/dev/null && echo "running" || echo "stopped"
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac
EOF
  chmod +x /etc/init.d/frps
  update-rc.d frps defaults
  /etc/init.d/frps start
else
  echo "Unknown init system"; exit 1
fi

# 清理
rm -rf "$TMP_DIR"

echo "\n========== frps 一键安装脚本 =========="
echo "认证方式: $auth"
echo "下载源: $mirror"
echo "架构: $ARCH_UNAME ($ARCH)"
echo "frps 版本: $VERSION_TAG"
echo "======================================="
