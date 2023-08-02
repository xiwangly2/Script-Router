#!/bin/bash

# 这里可能需要重新指定URL
download_url="http://vs8.top/scripts/"
# 推荐使用`bash <(curl -sSL vs8.top)`命令直接执行

# 检查系统是否安装了curl或wget
if command -v curl >/dev/null 2>&1; then
  # 使用curl从远程获取脚本
  download_command="curl -sSo"
elif command -v wget >/dev/null 2>&1; then
  # 使用wget从远程获取脚本
  download_command="wget -qO"
else
  echo "无法获取脚本，系统未安装curl或wget。"
  exit 1
fi

function execute_script() {
  local script_name=$1
  # 从远程下载脚本并执行
  $download_command "$script_name" "${download_url}$script_name"
  chmod +x "$script_name"
  ./"$script_name"
}

function show_main_menu() {
  echo "请输入选项："
  echo "-1. 执行快捷菜单(一些实用功能)"
  echo "1. 执行arch.sh脚本(查看架构)"
  echo "2. 执行install.sh脚本(没写)"
  echo "3. 执行update.sh脚本(没写)"
  echo "4. 执行uninstall.sh脚本(没写)"
  echo "5. 一键换清华源setup_sources.sh(支持多种发行版)"
}

function show_shortcut_menu() {
  echo "请输入选项："
  echo "1. 一键关闭SELinux(redhat系Linux需要)"
  echo "2. 一键允许root用户连接ssh"
  echo "3. 一键设置vi-tiny可以使用插入(Debian最小化安装可能出现的问题)"
  echo "4. 一键设置Linux系统代理"
  echo "5. 清除系统代理"
}

function execute_shortcut_menu() {
  local shortcut_choice=$1
  case $shortcut_choice in
    1)
      # 即时生效并永久关闭SELinux的命令
      sed -i 's/^SELINUX=.*/#&/;s/^SELINUXTYPE=.*/#&/;/SELINUX=.*/a SELINUX=disabled' /etc/sysconfig/selinux && /usr/sbin/setenforce 0
      ;;
    2)
      # 一键允许root用户连接ssh
      sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && /etc/init.d/ssh reload
      ;;
    3)
      # 设置vi-tiny可以使用插入
      sed -i 's/set compatible/set nocompatible/g' /etc/vim/vimrc.tiny
      ;;
    4)
      # 一键设置Linux系统代理
      echo "代理信息应按照"http://[[用户名][:密码]@]主机名[:端口]/"的标准形式给出，不需要引号"
      echo "请输入代理URL:"
      read proxy_url
      # Write the proxy settings to /etc/profile
      echo "export http_proxy=\"$proxy_url\"" | sudo tee -a /etc/profile
      echo "export https_proxy=\"$proxy_url\"" | sudo tee -a /etc/profile
      echo "export no_proxy=\"localhost,127.*,10.*,172.16.*,172.17.*,172.18.*,172.19.*,172.20.*,172.21.*,172.22.*,172.23.*,172.24.*,172.25.*,172.26.*,172.27.*,172.28.*,172.29.*,172.30.*,172.31.*,192.168.*\"" | sudo tee -a /etc/profile
      source /etc/profile
      echo "已设置代理：$proxy_url"
      ;;
    5)
      # 清除Linux系统代理
      # Remove proxy settings from /etc/profile
      unset http_proxy
      unset https_proxy
      unset no_proxy
      sed -i '/^export http_proxy/d' /etc/profile
      sed -i '/^export https_proxy/d' /etc/profile
      sed -i '/^export no_proxy/d' /etc/profile
      echo "已清除代理设置。"
      ;;
    *)
      echo "无效的快捷菜单选项"
      exit 1
      ;;
  esac
}

show_main_menu
read choice

case $choice in
  -1)
    show_shortcut_menu
    read shortcut_choice
    execute_shortcut_menu "$shortcut_choice"
    ;;
  1)
    execute_script "arch.sh"
    ;;
  2)
    execute_script "install.sh"
    ;;
  3)
    execute_script "update.sh"
    ;;
  4)
    execute_script "uninstall.sh"
    ;;
  5)
    execute_script "setup_sources.sh"
    ;;
  *)
    echo "无效的选项"
    exit 1
    ;;
esac
