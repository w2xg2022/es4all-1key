#!/bin/bash
# 所有阶段脚本共用的辅助函数。
set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main}"
ASSETS_DIR="${ASSETS_DIR:-/tmp/es4armbian-1key/assets}"
GAME_USER="${GAME_USER:-game}"
CONFIG_FILE="${CONFIG_FILE:-/tmp/es4armbian-1key/config}"

log()  { printf '\033[1;32m[1key]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[1key][警告]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[1key][错误]\033[0m %s\n' "$*" >&2; }

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        err "请用 root 执行（sudo bash $0）"
        exit 1
    fi
}

# 载入互动问答阶段写入的设定（HIDE_BOOTLOG / PLATFORMS / GAME_PASSWORD）
load_config() {
    HIDE_BOOTLOG="${HIDE_BOOTLOG:-yes}"
    PLATFORMS="${PLATFORMS:-fc sfc}"
    GAME_PASSWORD="${GAME_PASSWORD:-1234}"
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck disable=SC1090
        . "$CONFIG_FILE"
    fi
}

ensure_game_user() {
    if ! id "$GAME_USER" >/dev/null 2>&1; then
        log "建立使用者 $GAME_USER"
        useradd -m -G audio,video,input,render,netdev "$GAME_USER"
    else
        usermod -aG netdev "$GAME_USER"
    fi
}

set_game_password() {
    local pass="$1"
    log "设定使用者 $GAME_USER 的密码"
    echo "$GAME_USER:$pass" | chpasswd
}

# 下载素材到本地缓存（assets/ 目录），优先用仓库内已存在的档案，
# 否则从 GitHub raw 抓取，方便单独重跑各阶段脚本。
fetch_asset() {
    local rel_path="$1"
    local dest="$ASSETS_DIR/$rel_path"
    mkdir -p "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        return 0
    fi
    log "下载素材 $rel_path"
    curl -fsSL "$REPO_RAW_BASE/assets/$rel_path" -o "$dest"
}

backup_once() {
    local f="$1"
    if [ -e "$f" ] && [ ! -e "$f.orig" ]; then
        cp -a "$f" "$f.orig"
    fi
}
