# Script-Router
一个用 Go 语言写的脚本路由器（例如快捷拉取执行自用脚本）

突然发现用 PHP 顺带路由一下也不错

这个项目是我突发奇想折腾出来的，当时玩的虚拟机实在太多了，一个一个的改东西太麻烦了，于是索性自己手搓了一个Shell

后来发现GitHub上已经有大佬写好现成的了……

不过练练手也不错

## 开始

```bash
bash <(curl -sSL vs8.top)
```

## 输出示例

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
Disabled

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

参考
- https://github.com/SuperManito/LinuxMirrors