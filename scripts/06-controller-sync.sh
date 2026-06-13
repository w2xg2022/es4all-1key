#!/bin/bash
# 阶段 6：将 ES 的手柄按键设定（es_input.cfg）同步为 RetroArch autoconfig，
# 使用者在 ES「手柄和蓝牙设置」配置好的手柄可直接在 RetroArch / 游戏核心中使用。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh

require_root
load_config
ensure_game_user

GAME_HOME="$(getent passwd "$GAME_USER" | cut -d: -f6)"
ES_INPUT_CFG="$GAME_HOME/.emulationstation/es_input.cfg"
AUTOCONFIG_DIR="$GAME_HOME/.config/retroarch/autoconfig"

log "部署 ES 手柄设定 -> RetroArch autoconfig 转换脚本"
fetch_asset "scripts/es-input-to-retroarch.py"
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/es-input-to-retroarch.py" /usr/local/bin/es-input-to-retroarch.py

mkdir -p "$AUTOCONFIG_DIR"
chown -R "$GAME_USER:$GAME_USER" "$GAME_HOME/.config/retroarch"

if [ -f "$ES_INPUT_CFG" ]; then
    log "侦测到现有 es_input.cfg，立即同步一次"
    sudo -u "$GAME_USER" /usr/local/bin/es-input-to-retroarch.py "$ES_INPUT_CFG" "$AUTOCONFIG_DIR" || true
fi

log "设定 systemd 服务：手柄设定变更时自动同步到 RetroArch"
cat > /etc/systemd/system/es-controller-sync.service <<EOF
[Unit]
Description=将 ES 手柄设定同步到 RetroArch autoconfig

[Service]
Type=oneshot
User=$GAME_USER
Group=$GAME_USER
ExecStart=/usr/local/bin/es-input-to-retroarch.py $ES_INPUT_CFG $AUTOCONFIG_DIR
EOF

cat > /etc/systemd/system/es-controller-sync.path <<EOF
[Unit]
Description=监控 ES 手柄设定档变更

[Path]
PathModified=$ES_INPUT_CFG

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now es-controller-sync.path

log "阶段 6 完成"
