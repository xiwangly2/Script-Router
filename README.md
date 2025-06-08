# Script-Router
一个用 Go 语言写的脚本路由器（例如快捷拉取执行自用脚本）

突然发现用 PHP 顺带路由一下也不错

这个项目是我突发奇想折腾出来的，当时玩的虚拟机实在太多了，一个一个的改东西太麻烦了，于是索性自己手搓了一个Shell

后来发现GitHub上已经有大佬写好现成的了……

不过练练手也不错

## 开始

简短的一句话命令，如果系统上没有 bash 的话，可以使用 sh 或者 zsh 等等 shell 代替，使用 sh 执行可能有部分命令用不了
```bash
bash <(curl vs8.top)
```
或者使用 wget ：
```bash
bash <(wget -qO- vs8.top)
```

对于 sudo 提升的权限
```bash
sudo bash -c "$(curl -fsSL vs8.top)"
```

更通用的方法
```bash
curl -fsSL vs8.top -o main.sh
chmod +x main.sh
bash main.sh
```

## 功能
```bash
[root@localhost ~] bash <(curl -sL vs8.top)
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

[root@localhost ~] bash <(curl -sSL vs8.top)
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
bash <(curl vs8.top/frps.sh)
# oidc 配置
# bash <(curl vs8.top/frps-oidc.sh)
```

frpc
```bash
bash <(curl vs8.top/frpc.sh)
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
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable Script-Router
systemctl start Script-Router
# 查看状态
systemctl status Script-Router
# upload shell script to Workdirectory
curl http://localhost:28789
# 卸载
#systemctl stop Script-Router
#systemctl disable Script-Router
#rm -f /etc/systemd/system/Script-Router.service
```

参考
- https://github.com/SuperManito/LinuxMirrors