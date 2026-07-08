#!/bin/bash
# 阶段 4：部署 EmulationStation（从 es4all Release 下载，仅 KMSDRM 模式），
# 并依所选平台动态产生 es_systems.cfg / es_settings.cfg。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh
. ./platforms.sh

require_root
load_config
ensure_game_user

ES_RELEASE_URL="https://github.com/w2xg2022/es4all/releases/latest/download/emulationstation-armbian-aarch64.zip"
GAME_HOME="$(getent passwd "$GAME_USER" | cut -d: -f6)"
ES_HOME_CFG="$GAME_HOME/.emulationstation"

log "安装 EmulationStation 所需的动态库（libvlc 等）"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends libvlc5 libvlccore9

log "下载 EmulationStation (es4all latest release)"
TMPZIP="/tmp/es4all-1key/emulationstation.zip"
mkdir -p /tmp/es4all-1key
curl -fsSL "$ES_RELEASE_URL" -o "$TMPZIP"

log "部署到 /opt/emulationstation"
rm -rf /tmp/es4all-1key/es-extract
mkdir -p /tmp/es4all-1key/es-extract
unzip -oq "$TMPZIP" -d /tmp/es4all-1key/es-extract

# 若 zip 内有单一最上层目录（例如 emulationstation/），先把内容层级拉平
SRC_DIR="/tmp/es4all-1key/es-extract"
entries=("$SRC_DIR"/*)
if [ "${#entries[@]}" -eq 1 ] && [ -d "${entries[0]}" ]; then
    SRC_DIR="${entries[0]}"
fi

mkdir -p /opt/emulationstation
rm -rf /opt/emulationstation/*
cp -a "$SRC_DIR"/. /opt/emulationstation/
chmod +x /opt/emulationstation/emulationstation

log "依所选平台产生 es_systems.cfg：$PLATFORMS"
mkdir -p "$ES_HOME_CFG"
backup_once "$ES_HOME_CFG/es_systems.cfg"
{
    echo '<!-- This is the EmulationStation Systems configuration file. -->'
    echo '<systemList>'
    for code in $PLATFORMS; do
        esname="${PLATFORM_ESNAME[$code]:-}"
        [ -z "$esname" ] && continue
        romdir="${PLATFORM_ROMDIR[$code]}"
        echo "    <system>"
        echo "        <name>${esname}</name>"
        echo "        <fullname>${PLATFORM_FULLNAME[$code]}</fullname>"
        echo "        <path>$GAME_HOME/ROMs/${romdir}</path>"
        echo "        <extension>${PLATFORM_EXT[$code]}</extension>"
        echo "        <command>es4a-ra-launch retroarch -L $GAME_HOME/.config/retroarch/cores/${PLATFORM_CORE[$code]} %ROM%</command>"
        echo "        <platform>${esname}</platform>"
        echo "        <theme>${PLATFORM_THEME[$code]:-$esname}</theme>"
        echo "    </system>"
    done
    echo '</systemList>'
} > "$ES_HOME_CFG/es_systems.cfg"

log "套用 es_settings.cfg（简体中文等预设值）"
fetch_asset "emulationstation/es_settings.cfg"
backup_once "$ES_HOME_CFG/es_settings.cfg"
install -o "$GAME_USER" -g "$GAME_USER" -m 0644 \
    "$ASSETS_DIR/emulationstation/es_settings.cfg" "$ES_HOME_CFG/es_settings.cfg"

THEME_NAME="es-theme-alekfull-EmueELEC"
THEMES_DIR="$ES_HOME_CFG/themes"
if [ ! -d "$THEMES_DIR/$THEME_NAME" ]; then
    log "下载主题 $THEME_NAME"
    THEME_ZIP="/tmp/es4all-1key/${THEME_NAME}.zip"
    curl -fsSL "https://github.com/EmuELEC/${THEME_NAME}/archive/refs/heads/master.zip" -o "$THEME_ZIP"
    rm -rf /tmp/es4all-1key/theme-extract
    mkdir -p /tmp/es4all-1key/theme-extract "$THEMES_DIR"
    unzip -oq "$THEME_ZIP" -d /tmp/es4all-1key/theme-extract
    cp -a "/tmp/es4all-1key/theme-extract/${THEME_NAME}-master" "$THEMES_DIR/$THEME_NAME"
    rm -f "$THEME_ZIP"
    chown -R "$GAME_USER:$GAME_USER" "$THEMES_DIR"
else
    log "主题 $THEME_NAME 已存在，略过下载"
fi

# NOTE(w2xg2022): es-theme-alekfull-EmueELEC原版menuicons.xml没有定义iconEmuelec，
# 导致主菜单"EMUELEC设置"图标空白(不是图档问题，是这个key在主题里完全不存在)。
# Emuelec.png是从Crystal主题的彩色logo用ImageMagick转成白色单色剪影(保留alpha透明度)，
# 跟主题原生其他图标风格一致，套用colorShift才不会变成黑白反色。
# 放在if/else外面，不论主题是刚下载还是已存在(旧装置升级)都会套用。
MENUICONS_XML="$THEMES_DIR/$THEME_NAME/_inc/icons/menuicons.xml"
if [ -f "$MENUICONS_XML" ] && ! grep -q 'iconEmuelec' "$MENUICONS_XML"; then
    log "修复EMUELEC设置菜单图标缺失"
    fetch_asset "emulationstation/Emuelec.png"
    install -o "$GAME_USER" -g "$GAME_USER" -m 0644 \
        "$ASSETS_DIR/emulationstation/Emuelec.png" "$THEMES_DIR/$THEME_NAME/_inc/icons/Emuelec.png"
    sed -i 's|<iconAdvanced>./Advanced.png</iconAdvanced>|<iconAdvanced>./Advanced.png</iconAdvanced>\n            <iconEmuelec>./Emuelec.png</iconEmuelec>|' \
        "$MENUICONS_XML"
fi

for code in $PLATFORMS; do
    romdir="${PLATFORM_ROMDIR[$code]:-}"
    [ -z "$romdir" ] && continue
    mkdir -p "$GAME_HOME/ROMs/$romdir"
done

# 若 fc 平台已选用且 ROM 目录是空的，放入 240p Test Suite 作为示范 ROM，
# 避免使用者首次开机时因没有任何游戏而无法操作 EmulationStation
if [ -n "${PLATFORM_ROMDIR[fc]:-}" ]; then
    FC_ROMDIR="$GAME_HOME/ROMs/${PLATFORM_ROMDIR[fc]}"
    case " $PLATFORMS " in
        *" fc "*)
            if [ -d "$FC_ROMDIR" ] && [ -z "$(ls -A "$FC_ROMDIR" 2>/dev/null)" ]; then
                log "FC ROM 目录为空，放入示范 ROM（240p Test Suite）"
                fetch_asset "roms/fc/240pee.nes"
                fetch_asset "roms/fc/gamelist.xml"
                fetch_asset "roms/fc/media/images/240pee.png"
                install -m 0644 "$ASSETS_DIR/roms/fc/240pee.nes" "$FC_ROMDIR/240pee.nes"
                install -m 0644 "$ASSETS_DIR/roms/fc/gamelist.xml" "$FC_ROMDIR/gamelist.xml"
                mkdir -p "$FC_ROMDIR/media/images"
                install -m 0644 "$ASSETS_DIR/roms/fc/media/images/240pee.png" "$FC_ROMDIR/media/images/240pee.png"
            fi
            ;;
    esac
fi

log "部署主菜单背景音乐（BGM）"
MUSIC_DIR="$ES_HOME_CFG/music"
mkdir -p "$MUSIC_DIR"
if [ -z "$(ls -A "$MUSIC_DIR" 2>/dev/null)" ]; then
    fetch_asset "music/famicommunist-manifesto.ogg"
    install -m 0644 "$ASSETS_DIR/music/famicommunist-manifesto.ogg" "$MUSIC_DIR/famicommunist-manifesto.ogg"
fi

chown -R "$GAME_USER:$GAME_USER" "$GAME_HOME/ROMs" "$ES_HOME_CFG"

log "阶段 4 完成（仅支援 KMSDRM 模式，由阶段 5 设定开机自动启动）"
