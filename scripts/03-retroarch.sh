#!/bin/bash
# 阶段 3：部署 RetroArch + 使用者偏好设定 + 中文选单字体修正 + Samba
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh
. ./platforms.sh

require_root
load_config
ensure_game_user

GAME_HOME="$(getent passwd "$GAME_USER" | cut -d: -f6)"
RA_CFG_DIR="$GAME_HOME/.config/retroarch"

log "安装 RetroArch 与所选平台的 core：$PLATFORMS"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
CORE_PKGS="retroarch"
for code in $PLATFORMS; do
    pkg="${PLATFORM_PKG[$code]:-}"
    if [ -z "$pkg" ]; then
        warn "未知平台代号 $code，略过"
        continue
    fi
    CORE_PKGS="$CORE_PKGS $pkg"
done
apt-get install -y --no-install-recommends $CORE_PKGS

log "套用使用者偏好设定 (retroarch.cfg：简体中文介面、SELECT+START 退出游戏等)"
fetch_asset "retroarch/retroarch.cfg"
mkdir -p "$RA_CFG_DIR"
backup_once "$RA_CFG_DIR/retroarch.cfg"
install -o "$GAME_USER" -g "$GAME_USER" -m 0644 \
    "$ASSETS_DIR/retroarch/retroarch.cfg" "$RA_CFG_DIR/retroarch.cfg"

log "套用中文选单字体修正（取代 ozone 主题预设字型，修正选单乱码）"
fetch_asset "fonts/regular.ttf"
fetch_asset "fonts/bold.ttf"
FONT_DIR="$RA_CFG_DIR/assets/ozone/fonts"
mkdir -p "$FONT_DIR"
for f in regular.ttf bold.ttf; do
    backup_once "$FONT_DIR/$f"
    install -o "$GAME_USER" -g "$GAME_USER" -m 0644 "$ASSETS_DIR/fonts/$f" "$FONT_DIR/$f"
done
chown -R "$GAME_USER:$GAME_USER" "$RA_CFG_DIR"

log "建立 core 连结到 ~/.config/retroarch/cores（与 es_systems.cfg 路径对应）"
mkdir -p "$RA_CFG_DIR/cores"
for code in $PLATFORMS; do
    core="${PLATFORM_CORE[$code]:-}"
    [ -z "$core" ] && continue
    src="/usr/lib/$(uname -m)-linux-gnu/libretro/$core"
    if [ -f "$src" ]; then
        ln -sf "$src" "$RA_CFG_DIR/cores/$core"
    else
        warn "找不到 $src，请确认 ${PLATFORM_PKG[$code]} 套件的安装路径"
    fi
done
chown -R "$GAME_USER:$GAME_USER" "$RA_CFG_DIR/cores"

log "安装 Samba 以便上传 ROM"
apt-get install -y --no-install-recommends samba

SMB_CONF="/etc/samba/smb.conf"
backup_once "$SMB_CONF"
if ! grep -q '^\[ROMs\]' "$SMB_CONF" 2>/dev/null; then
    log "新增 [ROMs] 共享设定到 $SMB_CONF"
    cat >> "$SMB_CONF" <<EOF

[ROMs]
   path = $GAME_HOME/ROMs
   browseable = yes
   writable = yes
   guest ok = no
   valid users = $GAME_USER
   force user = $GAME_USER
   create mask = 0664
   directory mask = 0775
EOF
fi

log "设定 Samba 使用者 $GAME_USER（密码与系统密码一致）"
(echo "$GAME_PASSWORD"; echo "$GAME_PASSWORD") | smbpasswd -s -a "$GAME_USER"
smbpasswd -e "$GAME_USER"

systemctl enable smbd
systemctl restart smbd

log "阶段 3 完成"
log "备注：字体修正路径为 $FONT_DIR，若 MD1000 测试后发现 RetroArch 仍显示乱码，"
log "      表示实际选单字型路径不同，需要在这支脚本中调整 FONT_DIR。"
