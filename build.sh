#!/usr/bin/env bash
# 在当前机器上原生编译 udp2raw，产物输出到 bin/udp2raw_<os>_<arch>
# 用法：在目标平台（Linux / macOS）上执行 ./build.sh
# 可用环境变量 CXX 指定编译器，默认 g++（macOS 上 g++ 即 clang++）
set -e
cd "$(dirname "$0")"

CXX=${CXX:-g++}

# 源文件与编译选项和 makefile 保持一致
SOURCES="main.cpp lib/md5.cpp lib/pbkdf2-sha1.cpp lib/pbkdf2-sha256.cpp encrypt.cpp log.cpp network.cpp common.cpp connection.cpp misc.cpp fd_manager.cpp client.cpp server.cpp lib/aes_faster_c/aes.cpp lib/aes_faster_c/wrapper.cpp my_ev.cpp"
FLAGS="-std=c++11 -Wall -Wextra -Wno-unused-variable -Wno-unused-parameter -Wno-missing-field-initializers"

os=$(uname -s)
arch=$(uname -m)
case "$arch" in
    x86_64 | amd64) arch=amd64 ;;
    aarch64 | arm64) arch=arm64 ;;
esac

mkdir -p bin

gitver=$(git rev-parse HEAD 2>/dev/null || echo unknown)
echo "const char *gitversion = \"$gitver\";" > git_version.h

case "$os" in
    Linux)
        # Linux 用原生 raw socket 版本（对应 makefile 的 all 目标），优先静态链接
        out="bin/udp2raw_linux_${arch}"
        echo "==> 编译 $out (静态链接)"
        if ! $CXX -o "$out" -I. $SOURCES -isystem libev $FLAGS -lpthread -lrt -O2 -static; then
            echo "==> 静态链接失败，回退为动态链接"
            $CXX -o "$out" -I. $SOURCES -isystem libev $FLAGS -lpthread -lrt -O2
        fi
        ;;
    Darwin)
        # macOS 用多平台 libpcap 版本（对应 makefile 的 mac 目标），系统不支持静态链接
        out="bin/udp2raw_mac_${arch}"
        echo "==> 编译 $out"
        $CXX -o "$out" -I. $SOURCES -isystem libev $FLAGS -lpthread -lpcap -DUDP2RAW_MP -O2
        ;;
    *)
        echo "不支持的系统: $os（目前支持 Linux / macOS）" >&2
        exit 1
        ;;
esac

echo "==> 完成:"
ls -lh "$out"
file "$out" 2>/dev/null || true
