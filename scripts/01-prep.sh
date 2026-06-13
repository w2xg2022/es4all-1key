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
    fontconfig

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
