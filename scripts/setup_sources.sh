#!/bin/bash

# 显示支持的发行版列表
show_supported_distros() {
    echo "Supported Linux distributions:(Only the official original version is supported)"
    echo "1. Ubuntu 22.04 LTS"
    echo "2. Debian 12"
    echo "3. CentOS 7"
    echo "4. Fedora 30"
    echo "5. OpenBSD"
    echo "6. Alpine"
    echo "7. Arch Linux"
    echo "8. openSUSE Tumbleweed"
    echo "9. openSUSE Leap 15.3"
    echo "10. OpenWRT (LEDE)"

    # 添加其他发行版选项...
}

# 获取用户选择的发行版
get_distro_choice() {
    read -p "Enter your Linux distribution choice: " choice
    echo "$choice"
}

# 设置软件源
setup_sources() {
    local distro=$1

    case $distro in
        "1")
            echo "Setting up sources for Ubuntu 22.04 TLS..."
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            sed -i "s/mirrors.tuna.tsinghua.edu.cn/deb.debian.org/g" /etc/apt/sources.list && apt-get update
            ;;
        "2")
            echo "Setting up sources for Debian 12..."
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            sed -i "s/mirrors.tuna.tsinghua.edu.cn/deb.debian.org/g" /etc/apt/sources.list && apt-get update
            ;;
        "3")
            echo "Setting up sources for CentOS 7..."
            sed -e 's|^mirrorlist=|#mirrorlist=|g' \
         -e 's|^#baseurl=http://mirror.centos.org/centos|baseurl=https://mirrors.tuna.tsinghua.edu.cn/centos|g' \
         -i.bak \
         /etc/yum.repos.d/CentOS-*.repo
            yum makecache
            ;;
        "4")
            echo "Setting up sources for Fedora 30..."
            sed -e 's|^metalink=|#metalink=|g' \
         -e 's|^#baseurl=http://download.example/pub/fedora/linux|baseurl=https://mirrors.tuna.tsinghua.edu.cn/fedora|g' \
         -i.bak \
         /etc/yum.repos.d/fedora.repo \
         /etc/yum.repos.d/fedora-modular.repo \
         /etc/yum.repos.d/fedora-updates.repo \
         /etc/yum.repos.d/fedora-updates-modular.repo
            ;;
        "5")
            echo "Setting up sources for OpenBSD..."
            cp /etc/installurl /etc/installurl.bak
            echo "https://mirrors.tuna.tsinghua.edu.cn/OpenBSD/" | sudo tee /etc/installurl
            ;;
        "6")
            echo "Setting up sources for Alpine..."
            cp /etc/apk/repositories /etc/apk/repositories.bak
            sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
            ;;
        "7")
            echo "Setting up sources for Arch Linux..."
            cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
            echo "Server = https://mirrors.tuna.tsinghua.edu.cn/archlinux/\$repo/os/\$arch" | cat - /etc/pacman.d/mirrorlist > temp && mv temp /etc/pacman.d/mirrorlist
            pacman -Syyu
            ;;
        "8")
            echo "Setting up sources for openSUSE Tumbleweed..."
            zypper mr -da
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/tumbleweed/repo/oss/' mirror-oss
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/tumbleweed/repo/non-oss/' mirror-non-oss
            zypper ref
            ;;
        "9")
            echo "Setting up sources for openSUSE Leap 15.3..."
            zypper mr -da
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/distribution/leap/$releasever/repo/oss/' mirror-oss
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/distribution/leap/$releasever/repo/non-oss/' mirror-non-oss
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/update/leap/$releasever/oss/' mirror-update
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/update/leap/$releasever/non-oss/' mirror-update-non-oss
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/update/leap/$releasever/sle/' mirror-sle-update
            zypper ar -cfg 'https://mirrors.tuna.tsinghua.edu.cn/opensuse/update/leap/$releasever/backports/' mirror-backports-update
            ;;
        "10")
            echo "Setting up sources for OpenWRT (LEDE)..."
            cp /etc/opkg/distfeeds.conf /etc/opkg/distfeeds.conf.bak
            sed -i 's_downloads.openwrt.org_mirrors.tuna.tsinghua.edu.cn/openwrt_' /etc/opkg/distfeeds.conf
            ;;
        *)
            echo "Unsupported distribution. Exiting..."
            exit 1
            ;;
    esac
}

# 主函数
main() {
    show_supported_distros
    local distro_choice=$(get_distro_choice)

    setup_sources "$distro_choice"

    echo "Source setup completed."
}

main
