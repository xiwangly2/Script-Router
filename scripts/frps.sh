#!/bin/bash
set -eux

# 1. 依赖安装
if   command -v yum      >/dev/null; then INSTALL="yum install -y"
elif command -v dnf      >/dev/null; then INSTALL="dnf install -y"
elif command -v apt-get  >/dev/null; then INSTALL="apt-get install -y"
elif command -v apk      >/dev/null; then INSTALL="apk add --no-cache"
elif command -v zypper   >/dev/null; then INSTALL="zypper install -y"
elif command -v pacman   >/dev/null; then INSTALL="pacman -Sy --noconfirm"
else echo "Unsupported package manager"; exit 1; fi
$INSTALL curl tar

# 2. 获取最新版本号
VERSION_TAG=$(curl -sSL https://api.github.com/repos/fatedier/frp/releases/latest \
  | grep '"tag_name"' | head -1 | cut -d '"' -f4)
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
mv "frp_${VERSION}_linux_${ARCH}/frps" /usr/local/bin/frps
chmod +x /usr/local/bin/frps
mkdir -p /etc/frp
cat >/etc/frp/frps.toml <<EOF
bindAddr = "0.0.0.0"
bindPort = 7000

auth.method = "token"
auth.token = "xxx"

webServer.addr = "0.0.0.0"
webServer.port = 7500
webServer.user = "xiwangly"
webServer.password = "xxx"
EOF

# 6. Init 系统检测
if [ -d /run/systemd/system ]; then
  # systemd 服务单元
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
  # OpenRC 脚本
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
  # SysVinit 脚本
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

# 7. 清理
rm -rf "$TMP_DIR"
