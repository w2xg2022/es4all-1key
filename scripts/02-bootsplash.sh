#!/bin/bash
# 阶段 2：隐藏开机跑码 + 套用自定 Plymouth 开机画面
#
# 原理：
#   - 改用 Plymouth：在 extraargs 加入 splash，让 Plymouth 以图形模式启动并
#     覆盖开机文字；quiet/loglevel=0/vt.global_cursor_default=0/
#     systemd.show_status=0 进一步抑制内核与 systemd 的文字输出。
#   - ophub（如 MD1000）：预装 Plymouth "armbian" 主题，只需替换 watermark.png；
#     bootlogo 必须维持 false——bootlogo=true 时 boot.cmd 会注入 ophub 专有的
#     bootsplash.bootfile 机制，与 Plymouth 冲突。
#   - 标准 Armbian community（如 RK3318/RK3228H）：预装 plymouth/plymouth-themes
#     但没有 "armbian" 主题，改建立一个使用自定 watermark.png 的 es4armbian 主题；
#     bootlogo 必须设为 true——标准 boot.cmd 只有 bootlogo=true 时才会在
#     consoleargs 加入 "splash plymouth.ignore-serial-consoles"，否则会加入
#     "splash=verbose" 让 Plymouth 进入除错模式、直接把文字印到画面上。
#   - 两种情况都需重建 initramfs，让 Plymouth 开机画面能在早期阶段就接管画面。
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

if [ ! -f "$ENV_FILE" ]; then
    warn "找不到 $ENV_FILE（非 Armbian u-boot + armbianEnv.txt 环境，例如 devmfc/debian-on-amlogic 等），此阶段的隐藏开机跑码机制暂不支援，跳过阶段 2"
    exit 0
fi

# 判断 Armbian 来源：
#   - ophub（如 MD1000）：预装 Plymouth "armbian" 主题，只需替换 watermark.png
#   - community（标准 Armbian，如 RK3318/RK3228H）：预装 plymouth/plymouth-themes，
#     但没有 "armbian" 主题，需建立含自定 watermark.png 的 es4armbian 主题
if grep -q '^VENDOR="Armbian_community"' /etc/armbian-release 2>/dev/null; then
    BOARD_TYPE="community"
else
    BOARD_TYPE="ophub"
fi
log "侦测到 Armbian 来源：$BOARD_TYPE"

backup_once "$ENV_FILE"

# bootlogo 在两种来源下意义不同：
#   - ophub：boot.cmd 在 bootlogo=true 时会注入专有的 bootsplash.bootfile 机制，
#     与 Plymouth 冲突，必须维持 false。
#   - community（标准 Armbian boot.cmd）：bootlogo=true 时才会在 consoleargs 加入
#     "splash plymouth.ignore-serial-consoles"；bootlogo=false 则改加入
#     "splash=verbose"，会让 Plymouth 进入除错模式、直接把文字印到画面上，
#     图形开机画面完全不会显示。因此 community 必须设为 true。
if [ "$BOARD_TYPE" = "community" ]; then
    BOOTLOGO_VALUE="true"
else
    BOOTLOGO_VALUE="false"
fi

log "设定 $ENV_FILE：verbosity=0, bootlogo=$BOOTLOGO_VALUE（改用 Plymouth 接管开机画面）"
if grep -q '^verbosity=' "$ENV_FILE"; then
    sed -i 's/^verbosity=.*/verbosity=0/' "$ENV_FILE"
else
    echo 'verbosity=0' >> "$ENV_FILE"
fi
if grep -q '^bootlogo=' "$ENV_FILE"; then
    sed -i "s/^bootlogo=.*/bootlogo=$BOOTLOGO_VALUE/" "$ENV_FILE"
else
    echo "bootlogo=$BOOTLOGO_VALUE" >> "$ENV_FILE"
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

fetch_asset "watermark.png"
THEME_NAME=""

if [ "$BOARD_TYPE" = "ophub" ]; then
    THEME_DIR="/usr/share/plymouth/themes/armbian"
    if [ -d "$THEME_DIR" ]; then
        backup_once "$THEME_DIR/watermark.png"
        log "套用自定开机画面到 $THEME_DIR/watermark.png"
        install -m 0644 "$ASSETS_DIR/watermark.png" "$THEME_DIR/watermark.png"
        THEME_NAME="armbian"
    else
        warn "找不到 Plymouth armbian 主题目录 ($THEME_DIR)，跳过开机画面替换"
    fi
else
    if ! dpkg -s plymouth-themes >/dev/null 2>&1; then
        log "安装 plymouth/plymouth-themes（标准 Armbian 预设未配置开机画面主题）"
        apt-get update -qq
        apt-get install -y plymouth plymouth-themes
    fi
    THEME_NAME="es4armbian"
    THEME_DIR="/usr/share/plymouth/themes/$THEME_NAME"
    log "建立自订 Plymouth 主题 $THEME_NAME（全屏显示自定开机画面 watermark.png）"
    mkdir -p "$THEME_DIR"
    install -m 0644 "$ASSETS_DIR/watermark.png" "$THEME_DIR/watermark.png"
    cat > "$THEME_DIR/$THEME_NAME.plymouth" <<EOF
[Plymouth Theme]
Name=$THEME_NAME
Description=es4armbian custom boot splash
ModuleName=script

[script]
ImageDir=$THEME_DIR
ScriptFile=$THEME_DIR/$THEME_NAME.script
EOF
    cat > "$THEME_DIR/$THEME_NAME.script" <<'EOF'
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);

watermark_image = Image("watermark.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
watermark_sprite = Sprite(watermark_image.Scale(screen_width, screen_height));
watermark_sprite.SetX(0);
watermark_sprite.SetY(0);
watermark_sprite.SetZ(10000);
EOF
fi

if [ -n "$THEME_NAME" ]; then
    plymouth-set-default-theme -R "$THEME_NAME" || true
fi

log "重新生成 initramfs（含 Armbian 的 uInitrd 转换），让 Plymouth 开机画面能在早期阶段就接管画面"
UPDATE_INITRAMFS_CONF="/etc/initramfs-tools/update-initramfs.conf"
# ophub 内核包默认将 update_initramfs 设为 no，update-initramfs -u 会被跳过
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
