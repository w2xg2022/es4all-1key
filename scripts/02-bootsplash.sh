#!/bin/bash
# 阶段 2：隐藏开机跑码 + 套用自定 Plymouth 开机画面
#
# 原理：
#   - /boot/armbianEnv.txt 的 verbosity 控制 kernel log 是否灌到画面上，
#     bootlogo=true 则让 Plymouth 全萤幕覆盖开机过程。
#   - Plymouth "armbian" 主题的 watermark.png 是开机动画置中显示的图，
#     替换成 1920x1080 自定图即可盖掉整个开机画面。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh

require_root
load_config

if [ "$HIDE_BOOTLOG" != "yes" ]; then
    log "已选择不隐藏开机跑码，跳过阶段 2"
    exit 0
fi

ENV_FILE="/boot/armbianEnv.txt"
THEME_DIR="/usr/share/plymouth/themes/armbian"
WATERMARK="$THEME_DIR/watermark.png"

if [ ! -f "$ENV_FILE" ]; then
    err "找不到 $ENV_FILE，此脚本仅支援 Armbian (u-boot + armbianEnv.txt)"
    exit 1
fi

backup_once "$ENV_FILE"

log "设定 $ENV_FILE：verbosity=0, bootlogo=true"
if grep -q '^verbosity=' "$ENV_FILE"; then
    sed -i 's/^verbosity=.*/verbosity=0/' "$ENV_FILE"
else
    echo 'verbosity=0' >> "$ENV_FILE"
fi
if grep -q '^bootlogo=' "$ENV_FILE"; then
    sed -i 's/^bootlogo=.*/bootlogo=true/' "$ENV_FILE"
else
    echo 'bootlogo=true' >> "$ENV_FILE"
fi

if [ -d "$THEME_DIR" ]; then
    fetch_asset "watermark.png"
    backup_once "$WATERMARK"
    log "套用自定开机画面到 $WATERMARK"
    install -m 0644 "$ASSETS_DIR/watermark.png" "$WATERMARK"
    plymouth-set-default-theme -R armbian || true
else
    warn "找不到 Plymouth armbian 主题目录 ($THEME_DIR)，跳过开机画面替换"
fi

log "阶段 2 完成（需重启才会生效；可用 '$ENV_FILE.orig' 还原）"
