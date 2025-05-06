#!/bin/bash

# 创建初始化脚本
cat << 'EOF' > /usr/local/bin/init-once.sh
#!/bin/bash

# 设置随机主机名（12位小写字母数字组合）
hostnamectl set-hostname "debian12-$(tr -dc a-z0-9 </dev/urandom | head -c 12)"

# 清除并重新生成 machine-id
rm -f /etc/machine-id
systemd-machine-id-setup

# 删除 systemd 服务，确保只执行一次
systemctl disable init-once.service
rm -f /etc/systemd/system/init-once.service
rm -f /usr/local/bin/init-once.sh

# 重启系统
reboot
EOF

# 添加执行权限
chmod +x /usr/local/bin/init-once.sh

# 创建 systemd service 文件
cat << 'EOF' > /etc/systemd/system/init-once.service
[Unit]
Description=Initialize hostname and machine-id once
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/init-once.sh
RemainAfterExit=no

[Install]
WantedBy=multi-user.target
EOF

# 启用该服务
systemctl enable init-once.service

echo "✅ 初始化脚本和服务已创建并启用，下一次启动时将自动执行。"
