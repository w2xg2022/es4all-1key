#!/bin/bash
# 阶段 2：隐藏开机跑码 + 套用自定 Plymouth 开机画面
#
# 原理：
#   - 该内核未编译 CONFIG_BOOTSPLASH，ophub 自带的 bootlogo=true 开机图机制无效，
#     故 bootlogo 维持 false，不依赖该机制。
#   - 改用 Plymouth：在 extraargs 加入 splash，让 Plymouth 以图形模式启动并
#     覆盖开机文字；quiet/loglevel=0/vt.global_cursor_default=0/
#     systemd.show_status=0 进一步抑制内核与 systemd 的文字输出。
#   - Plymouth "armbian" 主题的 watermark.png 是开机画面置中显示的图，
#     替换成自定图后，重建 initramfs 让 Plymouth 在早期阶段就接管画面。
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

log "设定 $ENV_FILE：verbosity=0, bootlogo=false（此内核未支援 ophub 自带开机图，改用 Plymouth）"
if grep -q '^verbosity=' "$ENV_FILE"; then
    sed -i 's/^verbosity=.*/verbosity=0/' "$ENV_FILE"
else
    echo 'verbosity=0' >> "$ENV_FILE"
fi
if grep -q '^bootlogo=' "$ENV_FILE"; then
    sed -i 's/^bootlogo=.*/bootlogo=false/' "$ENV_FILE"
else
    echo 'bootlogo=false' >> "$ENV_FILE"
fi

log "设定 $ENV_FILE：extraargs 加入 splash quiet loglevel=0 vt.global_cursor_default=0 systemd.show_status=0 plymouth.ignore-serial-consoles"
if grep -q '^extraargs=' "$ENV_FILE"; then
    current="$(sed -n 's/^extraargs=//p' "$ENV_FILE" | head -n1)"
    # 移除旧版可能残留的 plymouth.enable=0（会让 Plymouth 完全不启动）
    current="$(echo "$current" | sed 's/plymouth\.enable=0//g')"
    # plymouth.ignore-serial-consoles：否则 Plymouth 侵测到 serial console 会强制使用纯文字 details 外挂，自定图完全不显示
    for opt in splash quiet loglevel=0 vt.global_cursor_default=0 systemd.show_status=0 plymouth.ignore-serial-consoles; do
        case " $current " in
            *" $opt "*) ;;
            *) current="$current $opt" ;;
        esac
    done
    # 压缩多余空白
    current="$(echo "$current" | tr -s ' ')"
    current="${current# }"
    current="${current% }"
    sed -i "s/^extraargs=.*/extraargs=$current/" "$ENV_FILE"
else
    echo 'extraargs=splash quiet loglevel=0 vt.global_cursor_default=0 systemd.show_status=0 plymouth.ignore-serial-consoles' >> "$ENV_FILE"
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

log "重新生成 initramfs（含 Armbian 的 uInitrd 转换），让 Plymouth 开机画面能在早期阶段就接管画面"
UPDATE_INITRAMFS_CONF="/etc/initramfs-tools/update-initramfs.conf"
# Armbian 内核包默认将 update_initramfs 设为 no，update-initramfs -u 会被跳过
# （包括 Armbian 专属的 initrd.img -> uInitrd 转换步骤，u-boot 实际读取的是 uInitrd）
# 因此临时改为 yes 以强制执行，完成后还原
if grep -q '^update_initramfs=no' "$UPDATE_INITRAMFS_CONF" 2>/dev/null; then
    sed -i 's/^update_initramfs=no/update_initramfs=yes/' "$UPDATE_INITRAMFS_CONF"
    update-initramfs -u -k "$(uname -r)"
    sed -i 's/^update_initramfs=yes/update_initramfs=no/' "$UPDATE_INITRAMFS_CONF"
else
    update-initramfs -u -k "$(uname -r)"
fi

log "阶段 2 完成（需重启才会生效；可用 '$ENV_FILE.orig' 还原）"
