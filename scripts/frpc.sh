#!/bin/bash
set -eux

# 1. 选择包管理器
if   command -v dnf      >/dev/null 2>&1; then INSTALL="dnf install --allowerasing -y"
elif command -v yum      >/dev/null 2>&1; then INSTALL="yum install -y"
elif command -v apt-get  >/dev/null 2>&1; then INSTALL="apt-get install -y"
elif command -v apk      >/dev/null 2>&1; then INSTALL="apk add --no-cache"
elif command -v zypper   >/dev/null 2>&1; then INSTALL="zypper install -y"
elif command -v pacman   >/dev/null 2>&1; then INSTALL="pacman -Sy --noconfirm"
else
  echo "Unsupported package manager"; exit 1
fi

# 检查 frpc 是否已安装
if [ -f /usr/local/bin/frpc ]; then
  echo "frpc 已安装，执行更新..."
else
  echo "frpc 未安装，执行安装..."
fi

# 2. 按需检测并安装依赖
for pkg in curl tar; do
  if ! command -v "$pkg" >/dev/null 2>&1; then
    echo "Package '$pkg' not detected. Installing..."
    $INSTALL "$pkg"
  else
    echo "Package '$pkg' is already installed. Skipping."
  fi
done

# 2. 获取最新版本号
VERSION_TAG=$(curl -sI https://github.com/fatedier/frp/releases/latest | grep -i location | sed -E 's/.*\/tag\/(v[0-9.]+).*/\1/')
# 去掉开头的 v，得到纯版本号
VERSION=${VERSION_TAG#v}


# 3. 架构检测
ARCH_UNAME=$(uname -m)
case "$ARCH_UNAME" in
  x86_64)  ARCH=amd64 ;;
  aarch64) ARCH=arm64 ;;
  armv7l)  ARCH=arm ;;
  *)       echo "Unsupported arch: $ARCH_UNAME"; exit 1 ;;
esac

# 4. 下载解压
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR"
curl -sSL -o frp.tar.gz \
  "https://github.com/fatedier/frp/releases/download/${VERSION_TAG}/frp_${VERSION}_linux_${ARCH}.tar.gz"
tar -xzf frp.tar.gz

# 5. 部署二进制与配置
mv -f "frp_${VERSION}_linux_${ARCH}/frpc" /usr/local/bin/frpc
chmod +x /usr/local/bin/frpc
# 仅首次安装时生成配置
mkdir -p /etc/frp
if [ ! -f /etc/frp/frpc.toml ]; then
  cat >/etc/frp/frpc.toml <<EOF
serverAddr = "frps.example.com"
serverPort = 7000

auth.method = "token"
auth.token = "xxx"

webServer.addr = "0.0.0.0"
webServer.port = 7400
webServer.user = "admin"
webServer.password = "xxx"
webServer.pprofEnable = false

# tls
#transport.tls.certFile = "/etc/frp/ssl/client.crt"
#transport.tls.keyFile = "/etc/frp/ssl/client.key"
#transport.tls.trustedCaFile = "/etc/frp/ssl/ca.crt"

[[proxies]]
name = "SSH demo"
type = "tcp"
localIP = "127.0.0.1"
localPort = 22
remotePort = 10022
EOF
else
  echo "/etc/frp/frpc.toml 已存在，跳过生成。"
fi

# 6. Init 系统检测
if [ -d /run/systemd/system ]; then
  # systemd 服务单元
  cat >/etc/systemd/system/frpc.service <<EOF
[Unit]
Description=frpc service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/frpc -c /etc/frp/frpc.toml
Restart=always

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable frpc
  systemctl start frpc

elif command -v rc-service >/dev/null; then
  # OpenRC 脚本
  cat >/etc/init.d/frpc <<'EOF'
#!/sbin/openrc-run
command="/usr/local/bin/frpc"
command_args="-c /etc/frp/frpc.toml"
pidfile="/var/run/frpc.pid"
depend() {
  need net
}
EOF
  chmod +x /etc/init.d/frpc
  rc-update add frpc default
  rc-service frpc start

elif [ -d /etc/init.d ]; then
  # SysVinit 脚本
  cat >/etc/init.d/frpc <<'EOF'
#!/bin/sh
### BEGIN INIT INFO
# Provides:          frpc
# Required-Start:    $network
# Required-Stop:     $network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: frp server daemon
### END INIT INFO

case "$1" in
  start)
    /usr/local/bin/frpc -c /etc/frp/frpc.toml &
    ;;
  stop)
    killall frpc
    ;;
  status)
    pidof frpc >/dev/null && echo "running" || echo "stopped"
    ;;
  *)
    echo "Usage: $0 {start|stop|status}"
    exit 1
    ;;
esac
EOF
  chmod +x /etc/init.d/frpc
  update-rc.d frpc defaults
  /etc/init.d/frpc start

else
  echo "Unknown init system"; exit 1
fi

# 7. 清理
rm -rf "$TMP_DIR"
