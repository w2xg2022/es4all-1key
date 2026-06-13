#!/bin/bash
# es4armbian-1key 一鍵安裝腳本
# 用法: curl -fsSL https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main/es4armbian-1key.sh | sudo bash
set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main}"
WORKDIR="/tmp/es4armbian-1key"
SCRIPT_DIR="$WORKDIR/scripts"

mkdir -p "$SCRIPT_DIR"

if [ "$(id -u)" -ne 0 ]; then
    echo "請用 root 執行（sudo bash $0 或透過 curl ... | sudo bash）" >&2
    exit 1
fi

# 判斷是本機執行（倉庫已存在於本機）還是 curl 一鍵執行（需下載腳本）
SELF_PATH="${BASH_SOURCE[0]:-}"
SELF_DIR=""
if [ -n "$SELF_PATH" ] && [ -f "$SELF_PATH" ]; then
    SELF_DIR="$(cd "$(dirname "$SELF_PATH")" && pwd)"
fi
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/scripts/00-common.sh" ]; then
    SCRIPT_DIR="$SELF_DIR/scripts"
else
    echo "[1key] 下載安裝腳本..."
    for f in 00-common.sh 01-prep.sh 02-bootsplash.sh 03-retroarch.sh 04-emulationstation.sh 05-autostart.sh; do
        curl -fsSL "$REPO_RAW_BASE/scripts/$f" -o "$SCRIPT_DIR/$f"
    done
    chmod +x "$SCRIPT_DIR"/*.sh
fi

export REPO_RAW_BASE

bash "$SCRIPT_DIR/01-prep.sh"
bash "$SCRIPT_DIR/02-bootsplash.sh"
bash "$SCRIPT_DIR/03-retroarch.sh"
bash "$SCRIPT_DIR/04-emulationstation.sh"
bash "$SCRIPT_DIR/05-autostart.sh"

echo "[1key] 全部完成！建議執行 'reboot' 重啟，開機後將自動進入 EmulationStation。"
