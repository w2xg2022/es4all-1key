#!/bin/bash
# 阶段 4：部署 EmulationStation（从 es4armbian Release 下载，仅 KMSDRM 模式），
# 并依所选平台动态产生 es_systems.cfg / es_settings.cfg。
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh
. ./platforms.sh

require_root
load_config
ensure_game_user

ES_RELEASE_URL="https://github.com/w2xg2022/es4armbian/releases/download/latest/emulationstation-armbian-aarch64.zip"
GAME_HOME="$(getent passwd "$GAME_USER" | cut -d: -f6)"
ES_HOME_CFG="$GAME_HOME/.emulationstation"

log "下载 EmulationStation (es4armbian latest release)"
TMPZIP="/tmp/es4armbian-1key/emulationstation.zip"
mkdir -p /tmp/es4armbian-1key
curl -fsSL "$ES_RELEASE_URL" -o "$TMPZIP"

log "部署到 /opt/emulationstation"
rm -rf /tmp/es4armbian-1key/es-extract
mkdir -p /tmp/es4armbian-1key/es-extract
unzip -oq "$TMPZIP" -d /tmp/es4armbian-1key/es-extract

mkdir -p /opt/emulationstation
cp -a /tmp/es4armbian-1key/es-extract/. /opt/emulationstation/
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
        echo "        <command>retroarch -L $GAME_HOME/.config/retroarch/cores/${PLATFORM_CORE[$code]} %ROM%</command>"
        echo "        <platform>${esname}</platform>"
        echo "        <theme>${esname}</theme>"
        echo "    </system>"
    done
    echo '</systemList>'
} > "$ES_HOME_CFG/es_systems.cfg"

log "套用 es_settings.cfg（简体中文等预设值）"
fetch_asset "emulationstation/es_settings.cfg"
backup_once "$ES_HOME_CFG/es_settings.cfg"
install -o "$GAME_USER" -g "$GAME_USER" -m 0644 \
    "$ASSETS_DIR/emulationstation/es_settings.cfg" "$ES_HOME_CFG/es_settings.cfg"

for code in $PLATFORMS; do
    romdir="${PLATFORM_ROMDIR[$code]:-}"
    [ -z "$romdir" ] && continue
    mkdir -p "$GAME_HOME/ROMs/$romdir"
done
chown -R "$GAME_USER:$GAME_USER" "$GAME_HOME/ROMs" "$ES_HOME_CFG"

log "阶段 4 完成（仅支援 KMSDRM 模式，由阶段 5 设定开机自动启动）"
