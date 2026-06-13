#!/bin/bash
# 阶段 1：环境检测与共用依赖安装
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh

require_root
load_config

log "系统信息：$(. /etc/os-release; echo "$PRETTY_NAME ($(uname -m))")"

log "安装共用依赖（polkitd/pkexec、SDL2 mixer、字型相关工具等）"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
    curl ca-certificates unzip \
    polkitd pkexec \
    libsdl2-mixer-2.0-0 \
    libfreeimage3 libcurl4 libpugixml1v5 \
    fontconfig \
    network-manager \
    bluez \
    alsa-ucm-conf

log "部署 batocera-wifi / batocera-config / batocera-bluetooth 兼容脚本（供 EmulationStation 网络与蓝牙设置使用）"
fetch_asset "scripts/batocera-wifi"
fetch_asset "scripts/batocera-config"
fetch_asset "scripts/batocera-bluetooth"
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/batocera-wifi" /usr/local/bin/batocera-wifi
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/batocera-config" /usr/local/bin/batocera-config
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/batocera-bluetooth" /usr/local/bin/batocera-bluetooth
# ES 以 _ENABLEEMUELEC 编译，isScriptingSupported() 检查的是
# /usr/bin/batocera/<name>（硬编码路径），故须额外部署一份到此处，
# 否则「网络设置」「蓝牙设置」相关菜单不会出现。
mkdir -p /usr/bin/batocera
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/batocera-wifi" /usr/bin/batocera/batocera-wifi
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/batocera-config" /usr/bin/batocera/batocera-config
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/batocera-bluetooth" /usr/bin/batocera/batocera-bluetooth

log "部署 emuelec-utils 兼容脚本（避免 ES 与游戏切换时跳出 'not found' 错误）"
fetch_asset "scripts/emuelec-utils"
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/emuelec-utils" /usr/bin/emuelec-utils

log "部署 ALSA 软件音量控制配置（启用 ES 音量设置菜单）"
fetch_asset "configs/asound.conf"
install -o root -g root -m 0644 "$ASSETS_DIR/configs/asound.conf" /etc/asound.conf

log "授予 ping 命令 cap_net_raw 权限（ES 以 game 一般用户检测网络连通性需要用到）"
setcap cap_net_raw+ep /bin/ping 2>/dev/null || setcap cap_net_raw+ep "$(command -v ping)"

ensure_game_user
set_game_password "$GAME_PASSWORD"

mkdir -p /tmp/es4armbian-1key

# 仅支援 KMSDRM（非 X11）模式，需要 /dev/dri
if [ -e /dev/dri/card0 ] || [ -e /dev/dri/card1 ]; then
    log "侦测到 /dev/dri，将使用 KMSDRM 模式启动 EmulationStation"
else
    warn "未侦测到 /dev/dri，KMSDRM 模式可能无法正常显示，请确认显示驱动"
fi

log "阶段 1 完成"
