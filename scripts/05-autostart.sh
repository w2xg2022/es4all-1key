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

# ★内外盘聚合挂在 ExecStartPre 上★（与 EmuELEC/ROCKNIX 同一套设计）
#   重新套用挂载要求 ROM 目录没有程序占用 = 必须先停 ES，挂在 ExecStartPre 上
#   这两件事就合并成同一个动作，不必再有一个「立即挂载」按钮。
#   三个前缀一个都不能少：
#     `-` 忽略失败 —— 聚合只是加值功能，ES 起不来是灾难等级，绝不能因为挂载脚本
#         出错就开不了机（脚本本身也一律 exit 0，这是第二道保险）。
#     `+` ★用 root 跑★ —— 本服务是 User=$GAME_USER，而 mount/umount 一般使用者做不到。
#         漏了它就是**静默失败**：ES 照常起来，只是游戏永远只有内盘那些。
#     脚本不存在时（还没同步过 profiles）由 `-` 吸收，同样不影响开机。
#   ES4ALL_ROMS：脚本预设找 \$HOME/roms，而 1key 的 ROM 根是 $GAME_HOME/ROMs（大写），
#         不指定的话它会在旁边生一个空目录，聚合出来的东西 ES 根本看不到。
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
Environment=HOME=$GAME_HOME
Environment=ES4ALL_ROMS=$GAME_HOME/ROMs
ExecStartPre=-+$GAME_HOME/.config/es4all/bin/es4all-storage.sh
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
