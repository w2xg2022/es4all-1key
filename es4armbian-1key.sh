#!/bin/bash
# es4armbian-1key 一键安装脚本
# 用法: curl -fsSL https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main/es4armbian-1key.sh | sudo bash
set -euo pipefail

REPO_RAW_BASE="${REPO_RAW_BASE:-https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main}"
WORKDIR="/tmp/es4armbian-1key"
SCRIPT_DIR="$WORKDIR/scripts"
CONFIG_FILE="$WORKDIR/config"

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
if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/scripts/00-common.sh" ]; then
    SCRIPT_DIR="$SELF_DIR/scripts"
else
    echo "[1key] 下载安装脚本..."
    for f in 00-common.sh platforms.sh 01-prep.sh 02-bootsplash.sh 03-retroarch.sh 04-emulationstation.sh 05-autostart.sh; do
        curl -fsSL "$REPO_RAW_BASE/scripts/$f" -o "$SCRIPT_DIR/$f"
    done
    chmod +x "$SCRIPT_DIR"/*.sh
fi

export REPO_RAW_BASE
. "$SCRIPT_DIR/platforms.sh"

# ---- 互动问答（用 curl | bash 执行时，从 /dev/tty 读取输入） ----
TTY="/dev/tty"
if [ ! -r "$TTY" ] || [ ! -w "$TTY" ]; then
    TTY=""
fi

ask() {
    local prompt="$1" default="$2" reply
    if [ -z "$TTY" ]; then
        echo "$default"
        return
    fi
    read -r -p "$prompt" reply <"$TTY" >"$TTY" 2>&1 || true
    echo "${reply:-$default}"
}

echo ""
echo "===== es4armbian-1key 安装设定 ====="

HIDE_BOOTLOG="$(ask "1) 是否隐藏开机跑码画面？[Y/n]: " "y")"
case "$HIDE_BOOTLOG" in
    [Nn]*) HIDE_BOOTLOG="no" ;;
    *) HIDE_BOOTLOG="yes" ;;
esac

echo ""
echo "2) 请选择要安装的游戏平台（可多选，用空格分隔编号，例如：1 2）"
i=1
declare -A INDEX_TO_CODE
for code in "${PLATFORM_CODES[@]}"; do
    echo "   $i) $code - ${PLATFORM_NAME[$code]}"
    INDEX_TO_CODE[$i]="$code"
    i=$((i+1))
done
DEFAULT_INDEXES=""
i=1
for code in "${PLATFORM_CODES[@]}"; do
    for d in $DEFAULT_PLATFORMS; do
        [ "$d" = "$code" ] && DEFAULT_INDEXES="$DEFAULT_INDEXES $i"
    done
    i=$((i+1))
done
DEFAULT_INDEXES="${DEFAULT_INDEXES# }"

SELECTED_INDEXES="$(ask "   请输入编号（直接 Enter 套用预设：$DEFAULT_INDEXES，对应 $DEFAULT_PLATFORMS）: " "$DEFAULT_INDEXES")"
PLATFORMS=""
for idx in $SELECTED_INDEXES; do
    code="${INDEX_TO_CODE[$idx]:-}"
    [ -n "$code" ] && PLATFORMS="$PLATFORMS $code"
done
PLATFORMS="${PLATFORMS# }"
[ -z "$PLATFORMS" ] && PLATFORMS="$DEFAULT_PLATFORMS"

echo ""
GAME_PASSWORD="$(ask "3) 请设定 game 使用者密码（直接 Enter 使用预设 1234）: " "1234")"

echo ""
echo "===== 设定确认 ====="
echo "隐藏开机跑码: $HIDE_BOOTLOG"
echo "安装平台: $PLATFORMS"
echo "game 密码: $GAME_PASSWORD"
echo "====================="
echo ""

cat > "$CONFIG_FILE" <<EOF
HIDE_BOOTLOG="$HIDE_BOOTLOG"
PLATFORMS="$PLATFORMS"
GAME_PASSWORD="$GAME_PASSWORD"
EOF

bash "$SCRIPT_DIR/01-prep.sh"
bash "$SCRIPT_DIR/02-bootsplash.sh"
bash "$SCRIPT_DIR/03-retroarch.sh"
bash "$SCRIPT_DIR/04-emulationstation.sh"
bash "$SCRIPT_DIR/05-autostart.sh"

echo "[1key] 全部完成！建议执行 'reboot' 重启，开机后将自动进入 EmulationStation。"
echo "[1key] Samba 已启用，可用 game / $GAME_PASSWORD 上传 ROM 到 \\\\<装置IP>\\ROMs"
