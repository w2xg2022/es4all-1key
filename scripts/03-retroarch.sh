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

log "部署 RA 启动包装脚本（把 ES 选定的语系透传给 RetroArch）"
# es_systems.cfg 的 <command> 会改成透过这支脚本启动 retroarch：
# 每次进游戏前，读取 ES 的 es_settings.cfg 语系，换算成 RetroArch 的 user_language
# 数值写回 retroarch.cfg，再 exec 真正的 retroarch，达成 ES 语系 -> RA 选单语系同步。
RA_LAUNCH="/usr/local/bin/es4a-ra-launch"
cat > "$RA_LAUNCH" <<'EOF'
#!/bin/bash
# ES 语系 -> RetroArch user_language 透传启动器（由 es4all-1key 部署）
ES_SETTINGS="$HOME/.emulationstation/es_settings.cfg"
RA_CFG="$HOME/.config/retroarch/retroarch.cfg"
lang="$(sed -n 's/.*name="Language" value="\([^"]*\)".*/\1/p' "$ES_SETTINGS" 2>/dev/null | head -n1)"
case "$lang" in
    zh_CN) n=12 ;;   # 简体中文
    zh_TW) n=11 ;;   # 繁体中文
    ja_JP) n=1  ;;
    ko_KR) n=10 ;;
    fr_FR) n=2  ;;
    de_DE) n=4  ;;
    es_ES) n=3  ;;
    it_IT) n=5  ;;
    pt_BR) n=7  ;;
    ru_RU) n=9  ;;
    *)     n=0  ;;   # 其余一律英文
esac
if [ -f "$RA_CFG" ]; then
    if grep -q '^user_language' "$RA_CFG"; then
        sed -i "s/^user_language = .*/user_language = \"$n\"/" "$RA_CFG"
    else
        echo "user_language = \"$n\"" >> "$RA_CFG"
    fi
fi
exec "$@"
EOF
chmod 0755 "$RA_LAUNCH"

log "部署手柄按键位置对齐 remap（游戏内按物理位置，不按印刷字母）"
# 前提：autoconfig 里面键已按物理位置固定编号（udev 语义码：南=0/东=1/北=2/西=3，
# 见 es-input-to-retroarch.py），此时 RetroPad 几何为 A=东 B=南 X=北 Y=西。
# PS 系核心符号：✕=RetroPad B、○=A、□=Y、△=X。不加 remap 时南键→RetroPad A→○(错，应✕)，
# 所以只需把 A/B 互换即可让「南=✕、东=○」；X/Y（北=△、西=□）本就对齐，不能动。
# 因为编号是位置锚定的，这一份 remap 任天堂/Xbox 手柄通吃（已在 MD1000 实测验证）。
for code in $PLATFORMS; do
    corename="${PLATFORM_CORENAME[$code]:-}"
    [ -z "$corename" ] && continue
    remap_dir="$RA_CFG_DIR/config/remaps/$corename"
    mkdir -p "$remap_dir"
    cat > "$remap_dir/$corename.rmp" <<'EOF'
input_player1_btn_a = "0"
input_player1_btn_b = "8"
EOF
done
chown -R "$GAME_USER:$GAME_USER" "$RA_CFG_DIR/config/remaps"

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
    tmpzip="/tmp/es4all-1key/${core}.zip"
    curl -fsSL "$CORE_BUILDBOT_BASE/${core}.zip" -o "$tmpzip"
    unzip -oq "$tmpzip" -d "$RA_CFG_DIR/cores"
    rm -f "$tmpzip"
done
chown -R "$GAME_USER:$GAME_USER" "$RA_CFG_DIR/cores"

case " $PLATFORMS " in
    *" psp "*)
        log "PSP (ppsspp_libretro.so) 需要 libOpenGL.so.0，安装 libopengl0"
        apt-get install -y --no-install-recommends libopengl0

        log "套用 PSP (PPSSPP) core 设定：frameskip=1 释放 CPU 余裕给 ATRAC3+ 背景音乐解码，关闭各向异性过滤减轻 Mali-G52 负担"
        # 症状：带 ATRAC3+ 压缩背景音乐的 PSP 游戏（NBA Live、街霸 Alpha3 等）
        # 进选单/游戏后音效断续、沙沙声，纯音效（无 BGM）时正常。
        # 根因：音频同步绑在模拟速度上，ATRAC3+ 媒体引擎解码的 CPU 尖峰
        # 让模拟掉到 100% 以下就断音。frameskip=1 每帧空出时间喂给解码，
        # 实测 MD1000(RK3566) 上明显改善。各向异性 16x 对 Mali-G52 是纯浪费。
        PSP_OPT_DIR="$RA_CFG_DIR/config/PPSSPP"
        mkdir -p "$PSP_OPT_DIR"
        cat > "$PSP_OPT_DIR/PPSSPP.opt" <<'EOF'
ppsspp_frameskip = "1"
ppsspp_auto_frameskip = "enabled"
ppsspp_texture_anisotropic_filtering = "Off"
ppsspp_lazy_texture_caching = "enabled"
ppsspp_frame_duplication = "disabled"
ppsspp_internal_resolution = "480x272"
ppsspp_io_timing_method = "Fast"
EOF
        chown -R "$GAME_USER:$GAME_USER" "$PSP_OPT_DIR"
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
