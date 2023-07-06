#!/bin/sh
# 原始架构信息
get_arch="$(arch)";
if [[ $? != 0 ]];then get_arch=$(uname -m);fi;
# 架构别名
# 对应：kms
if [[ $get_arch =~ "x86_64" ]];then
    use_arch="amd64";
elif [[ $get_arch =~ "aarch64" ]];then
    use_arch="arm64";
elif [[ $get_arch =~ "arm" ]];then
    use_arch="armv7";
elif [[ $get_arch =~ "mips64" ]];then
    use_arch="mips64";
elif [[ $get_arch =~ "mips" ]];then
    use_arch="mips";
elif [[ $get_arch =~ "i686" ]];then
    use_arch="686";
elif [[ $get_arch =~ "i386" ]];then
    use_arch="386";
elif [[ $get_arch =~ "alpha" ]];then
    use_arch="alpha";
elif [[ $get_arch =~ "x86" ]];then
    use_arch="386";
elif [[ $get_arch =~ "wasm32" ]];then
    use_arch="wasm32";
else
    use_arch=$get_arch;
fi
export ARCH=$use_arch;
echo "The system architecture is \"${get_arch}\". Use \"${ARCH}\"";