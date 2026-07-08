#!/bin/bash
# 阶段 5：开机自动登入并启动 EmulationStation（KMSDRM 模式）
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh

require_root
load_config
ensure_game_user

GAME_HOME="$(getent passwd "$GAME_USER" | cut -d: -f6)"

log "停用 tty1 的 getty，避免与自动登入服务抢占终端"
systemctl disable --now getty@tty1.service 2>/dev/null || true

if [ "$HIDE_ALSA_ERRORS" = "yes" ]; then
    log "设定 systemd 服务：以 $GAME_USER 自动登入 tty1 并启动 EmulationStation（KMSDRM，过滤 ALSA/KMSDRM 无害错误讯息）"
    EXEC_START='/bin/bash -c '\''exec /opt/emulationstation/emulationstation 2> >(grep -v --line-buffered -E "ALSA lib|Error initializing SDL|kmsdrm not available|Renderer failed to initialize|Window failed to initialize" >&2)'\'''
else
    log "设定 systemd 服务：以 $GAME_USER 自动登入 tty1 并启动 EmulationStation（KMSDRM）"
    EXEC_START='/opt/emulationstation/emulationstation'
fi

cat > /etc/systemd/system/es4all.service <<EOF
[Unit]
Description=es4all EmulationStation (KMSDRM)
After=systemd-user-sessions.service getty@tty1.service
Conflicts=getty@tty1.service

[Service]
User=$GAME_USER
Group=$GAME_USER
PAMName=login
TTYPath=/dev/tty1
StandardInput=tty
StandardOutput=tty
Environment=SDL_VIDEODRIVER=kmsdrm
ExecStart=$EXEC_START
Restart=always
RestartSec=2

[Install]
WantedBy=graphical.target
EOF

log "启用 es4all.service（开机自动进入 EmulationStation）"
systemctl daemon-reload
systemctl enable es4all.service

log "阶段 5 完成"
log "提示：请重启测试（reboot）。若要先在桌面测试，可手动执行："
log "      systemctl start es4all.service"
