#!/bin/bash
# es4all-1key 一键反安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/w2xg2022/es4all-1key/main/es4all-1key-uninstall.sh | sudo bash
set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/w2xg2022/es4all-1key/main}"
WORKDIR="/tmp/es4all-1key"
SCRIPT_DIR="$WORKDIR/scripts"

mkdir -p "$SCRIPT_DIR"

if [ "$(id -u)" -ne 0 ]; then
    echo "请用 root 执行（sudo bash $0 或透过 curl ... | sudo bash）" >&2
    exit 1
fi

# 判断是本机执行（仓库已存在于本机）还是 curl 一键执行（需下载脚本）
SELF_PATH="${BASH_SOURCE[0]:-}"
SELF_DIR=""
if [ -n "$SELF_PATH" ] && [ -f "$SELF_PATH" ]; then
    SELF_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
fi
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/scripts/uninstall.sh" ]; then
    SCRIPT_DIR="$SELF_DIR/scripts"
else
    echo "[1key] 下载反安装脚本..."
    for f in 00-common.sh uninstall.sh; do
        curl -fsSL "$REPO_RAW_BASE/scripts/$f" -o "$SCRIPT_DIR/$f"
    done
    chmod +x "$SCRIPT_DIR"/*.sh
fi

export REPO_RAW_BASE
bash "$SCRIPT_DIR/uninstall.sh"
