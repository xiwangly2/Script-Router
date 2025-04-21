#!/bin/bash

# Here you may need to specify the URL again
download_url="http://vs8.top/scripts/"
# It is recommended to use the command 'bash <(curl -sSL vs8.top)' to execute directly.

# Check if curl or wget is installed on the system
if command -v curl >/dev/null 2>&1; then
  # Use curl to fetch the script from the remote
  download_command="curl -sSo"
elif command -v wget >/dev/null 2>&1; then
  # Use wget to fetch the script from the remote
  download_command="wget -qO"
elif command -v fetch >/dev/null 2>&1; then
  # Use fetch to fetch the script from the remote
  download_command="fetch -o"
elif command -v axel >/dev/null 2>&1; then
  # Use axel to fetch the script from the remote
  download_command="axel -o"
else
  echo "Unable to fetch the script. curl or wget is not installed on the system."
  exit 1
fi

function execute_script() {
  local script_name=$1
  # Download the script from the remote and execute it
  tmp_script=$(mktemp)
  $download_command "$tmp_script" "${download_url}$script_name"
  tr -d '\r' < "$tmp_script" > "$tmp_script.tmp" && mv "$tmp_script.tmp" "$tmp_script"
  chmod +x "$tmp_script"
  "$tmp_script"
  rm "$tmp_script" # Remove the temporary script file
}

function show_main_menu() {
  echo "Please enter your choice:"
  echo "[0] Execute the shortcut menu (some useful functions)"
  echo "[1] Execute arch.sh script (view architecture)"
  echo "[2] Execute install.sh script (not written)"
  echo "[3] Execute update.sh script (not written)"
  echo "[4] Execute uninstall.sh script (not written)"
  echo "[5] One-click switch to Tsinghua sources setup_sources.sh (supports multiple distributions)"
  echo "[1panel] One-click install 1Panel (based on your OS)"
}

function show_shortcut_menu() {
  echo "Please enter your choice:"
  echo "[1] One-click disable SELinux (required for Red Hat-based Linux)"
  echo "[1.1] One-click disable firewalld (required for Red Hat-based Linux)"
  echo "[2] One-click allow root user to connect via SSH"
  echo "[3] One-click set vi-tiny to enable insert mode (Debian minimal installation may encounter issues)"
  echo "[4] One-click set up the Linux system proxy"
  echo "[5] Clear the system proxy"
  echo "[6] One-click install Docker (using the official one-click script)"
  echo "[7] One-click configure Docker buildx (using the tonistiigi/binfmt image)"
  echo "[8] One-click build and install yay (An AUR Helper Written in Go, ArchLinux)"
}

function execute_shortcut_menu() {
  local shortcut_choice=$1
  case $shortcut_choice in
    1)
      # Command to immediately disable and permanently disable SELinux
      sed -i 's/^SELINUX=.*/#&/;s/^SELINUXTYPE=.*/#&/;/SELINUX=.*/a SELINUX=disabled' /etc/selinux/config
      sed -i 's/^SELINUX=.*/#&/;s/^SELINUXTYPE=.*/#&/;/SELINUX=.*/a SELINUX=disabled' /etc/sysconfig/selinux && /usr/sbin/setenforce 0
      ;;
    1.1)
      # Command to immediately disable firewalld and permanently disable firewalld
      systemctl disable firewalld.service && systemctl stop firewalld.service
      ;;
    2)
      # One-click allow root user to connect via SSH
      sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config && /etc/init.d/ssh reload
      ;;
    3)
      # Set vi-tiny to enable insert mode
      sed -i 's/set compatible/set nocompatible/g' /etc/vim/vimrc.tiny
      ;;
    4)
      # One-click set up the Linux system proxy
      echo "Proxy information should be provided in the standard form of 'http://[[username][:password]@]hostname[:port]/', without the quotes."
      echo "Please enter the proxy URL:"
      read -r proxy_url
      no_proxy_url="localhost,127.*,10.*,172.16.*,172.17.*,172.18.*,172.19.*,172.20.*,172.21.*,172.22.*,172.23.*,172.24.*,172.25.*,172.26.*,172.27.*,172.28.*,172.29.*,172.30.*,172.31.*,192.168.*"
      # Write the proxy settings to /etc/profile
      echo "export http_proxy=\"$proxy_url\"" | tee -a /etc/profile
      echo "export https_proxy=\"$proxy_url\"" | tee -a /etc/profile
      echo "export no_proxy=\"$no_proxy_url\"" | tee -a /etc/profile
      source /etc/profile
      echo "Proxy set: $proxy_url"
      ;;
    5)
      # Clear the Linux system proxy
      # Remove proxy settings from /etc/profile
      sed -i '/^export http_proxy/d' /etc/profile
      sed -i '/^export https_proxy/d' /etc/profile
      sed -i '/^export no_proxy/d' /etc/profile
      source /etc/profile
      echo "Proxy settings cleared."
      ;;
    6)
      # One-click install Docker
      $download_command get_docker.sh https://get.docker.com
      chmod +x get_docker.sh
      ./get_docker.sh
      ;;
    7)
      # One-click configure Docker buildx
      docker run --rm --privileged tonistiigi/binfmt:latest --install all
      docker buildx create --name mybuilder --driver docker-container
      docker buildx use mybuilder
      ;;
    8)
      # One-click build and install yay
      pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si
      ;;
    *)
      echo "Invalid shortcut menu option"
      exit 1
      ;;
  esac
}

function install_1panel_by_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    distro=$ID
  else
    echo "Unable to detect OS type. Please install 1Panel manually."
    exit 1
  fi

  echo "Detected OS: $distro"

  case "$distro" in
    ubuntu)
      echo "Installing 1Panel for Ubuntu..."
      sudo curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sudo bash quick_start.sh
      ;;
    debian)
      echo "Installing 1Panel for Debian..."
      curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && bash quick_start.sh
      ;;
    centos|rhel)
      echo "Installing 1Panel for CentOS/RedHat..."
      curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sh quick_start.sh
      ;;
    openeuler|anolis|kylin|uos)
      echo "Installing Docker and 1Panel for openEuler or similar systems..."
      bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
      curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sh quick_start.sh
      ;;
    *)
      echo "Unknown OS type. Using generic method: install Docker and 1Panel..."
      bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
      curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && sh quick_start.sh
      ;;
  esac
}

show_main_menu
read -r choice

case $choice in
  0)
    show_shortcut_menu
    read -r shortcut_choice
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
  1panel)
    install_1panel_by_os
  *)
    echo "Invalid option"
    exit 1
    ;;
esac
