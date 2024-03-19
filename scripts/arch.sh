#!/bin/bash

if arch=$(arch); then
    :
else
    arch=$(uname -m)
fi

get_arch() {

    if [[ $arch =~ "x86_64" ]]; then
        use_arch="amd64"
    elif [[ $arch =~ "aarch64" ]]; then
        use_arch="arm64"
    elif [[ $arch =~ "arm" ]]; then
        use_arch="armv7"
    elif [[ $arch =~ "mips64" ]]; then
        use_arch="mips64"
    elif [[ $arch =~ "mips" ]]; then
        use_arch="mips"
    elif [[ $arch =~ "i686" ]]; then
        use_arch="686"
    elif [[ $arch =~ "i386" ]]; then
        use_arch="386"
    elif [[ $arch =~ "alpha" ]]; then
        use_arch="alpha"
    elif [[ $arch =~ "x86" ]]; then
        use_arch="386"
    elif [[ $arch =~ "wasm32" ]]; then
        use_arch="wasm32"
    else
        use_arch=$arch
    fi

    echo "$use_arch"
}

# 调用函数获取架构
ARCH=$(get_arch)
use_arch=$ARCH
echo "The system architecture is \"$(arch)\". Use \"$use_arch\""
