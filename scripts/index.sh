#!/bin/bash

# 这里可能需要重新指定URL
download_url="http://192.168.85.1/"

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

echo "请输入选项："
echo "1. 执行arch.sh脚本"
echo "2. 执行install.sh脚本"
echo "3. 执行update.sh脚本"
echo "4. 执行uninstall.sh脚本"
read choice

case $choice in
  1)
    # 从远程下载arch.sh脚本并执行
    $download_command arch.sh "${download_url}arch.sh"
    chmod +x arch.sh
    ./arch.sh
    ;;
  2)
    # 从远程下载install.sh脚本并执行
    $download_command install.sh "${download_url}install.sh"
    chmod +x update.sh
    ./install.sh
    ;;
  3)
      # 从远程下载update.sh脚本并执行
      $download_command update.sh "${download_url}update.sh"
      chmod +x update.sh
      ./update.sh
      ;;
  4)
      # 从远程下载uninstall.sh脚本并执行
      $download_command uninstall.sh "${download_url}uninstall.sh"
      chmod +x uninstall.sh
      ./uninstall.sh
      ;;
  *)
    echo "无效的选项"
    exit 1
    ;;
esac
