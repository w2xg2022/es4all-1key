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

log "安装 RetroArch"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends retroarch

log "套用使用者偏好设定 (retroarch.cfg：简体中文介面、SELECT+START 退出游戏等)"
fetch_asset "retroarch/retroarch.cfg"
mkdir -p "$RA_CFG_DIR"
backup_once "$RA_CFG_DIR/retroarch.cfg"
install -o "$GAME_USER" -g "$GAME_USER" -m 0644 \
    "$ASSETS_DIR/retroarch/retroarch.cfg" "$RA_CFG_DIR/retroarch.cfg"

log "套用中文选单字体修正（菜单为 xmb，修正 xmb_font 指向自订中文字体）"
fetch_asset "fonts/regular.ttf"
fetch_asset "fonts/bold.ttf"
FONT_DIR="$RA_CFG_DIR/assets/xmb/fonts"
mkdir -p "$FONT_DIR"
for f in regular.ttf bold.ttf; do
    backup_once "$FONT_DIR/$f"
    install -o "$GAME_USER" -g "$GAME_USER" -m 0644 "$ASSETS_DIR/fonts/$f" "$FONT_DIR/$f"
done
chown -R "$GAME_USER:$GAME_USER" "$RA_CFG_DIR"

XMB_FONT_PATH="$FONT_DIR/regular.ttf"
if grep -q '^xmb_font' "$RA_CFG_DIR/retroarch.cfg"; then
    sed -i "s|^xmb_font = .*|xmb_font = \"$XMB_FONT_PATH\"|" "$RA_CFG_DIR/retroarch.cfg"
else
    echo "xmb_font = \"$XMB_FONT_PATH\"" >> "$RA_CFG_DIR/retroarch.cfg"
fi

log "套用中文 OSD 提示字体修正（video_font_path 留空时只会用内建字体，中文显示为方块）"
if grep -q '^video_font_path' "$RA_CFG_DIR/retroarch.cfg"; then
    sed -i "s|^video_font_path = .*|video_font_path = \"$XMB_FONT_PATH\"|" "$RA_CFG_DIR/retroarch.cfg"
else
    echo "video_font_path = \"$XMB_FONT_PATH\"" >> "$RA_CFG_DIR/retroarch.cfg"
fi
chown "$GAME_USER:$GAME_USER" "$RA_CFG_DIR/retroarch.cfg"

log "从 libretro buildbot 下载所选平台的 core：$PLATFORMS"
mkdir -p "$RA_CFG_DIR/cores"
for code in $PLATFORMS; do
    core="${PLATFORM_CORE[$code]:-}"
    if [ -z "$core" ]; then
        warn "未知平台代号 $code，略过"
        continue
    fi
    [ -f "$RA_CFG_DIR/cores/$core" ] && continue
    log "下载 $core"
    tmpzip="/tmp/es4armbian-1key/${core}.zip"
    curl -fsSL "$CORE_BUILDBOT_BASE/${core}.zip" -o "$tmpzip"
    unzip -oq "$tmpzip" -d "$RA_CFG_DIR/cores"
    rm -f "$tmpzip"
done
chown -R "$GAME_USER:$GAME_USER" "$RA_CFG_DIR/cores"

case " $PLATFORMS " in
    *" psp "*)
        log "PSP (ppsspp_libretro.so) 需要 libOpenGL.so.0，安装 libopengl0"
        apt-get install -y --no-install-recommends libopengl0
        ;;
esac

case " $PLATFORMS " in
    *" n64 "*)
        log "套用 N64 (parallel_n64) core 设定：angrylion 软件渲染，避免 GL/GLES 硬件上下文不兼容导致崩溃"
        N64_OPT_DIR="$RA_CFG_DIR/config/ParaLLEl N64"
        mkdir -p "$N64_OPT_DIR"
        cat > "$N64_OPT_DIR/ParaLLEl N64.opt" <<'EOF'
parallel-n64-cpucore = "cached_interpreter"
parallel-n64-gfxplugin = "angrylion"
EOF
        chown -R "$GAME_USER:$GAME_USER" "$N64_OPT_DIR"
        ;;
esac

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
