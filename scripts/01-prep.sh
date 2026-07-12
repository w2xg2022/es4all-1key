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
    alsa-ucm-conf \
    locales tzdata

log "锁定预设时区为 Asia/Shanghai (UTC+8)"
# es4all 面向简体中文用户，统一锁 UTC+8；底层 Armbian 映像默认多为 Etc/UTC，
# 不显式设定会让存档时间戳、金手指/成就时间等整机差 8 小时。
ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" > /etc/timezone
timedatectl set-timezone Asia/Shanghai 2>/dev/null || true

log "生成并锁定预设系统语系为简体中文 (zh_CN.UTF-8)"
# ES / RetroArch 各有内建语系(靠 es_settings / user_language)，但系统层(SSH/终端/
# 系统消息)默认 en_US。生成并锁 zh_CN.UTF-8 让整机预设即简体中文。
# 注意：只写入 /etc/default/locale 影响「后续」会话，本次安装仍在原语系下跑，不受影响。
if [ -f /etc/locale.gen ]; then
    sed -i 's/^# *\(zh_CN.UTF-8 UTF-8\)/\1/' /etc/locale.gen
    grep -q '^zh_CN.UTF-8 UTF-8' /etc/locale.gen || echo 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
fi
locale-gen zh_CN.UTF-8
# 显式覆盖 LC_MESSAGES：部分 Armbian 映像 /etc/default/locale 预置了
# LC_MESSAGES=en_US.UTF-8，若不覆盖会盖过 LANG 让系统消息仍是英文，
# 且与 LANGUAGE=zh_CN 冲突导致 update-locale 自动禁用 LANGUAGE。
update-locale LANG=zh_CN.UTF-8 LC_MESSAGES=zh_CN.UTF-8 LANGUAGE=zh_CN:zh

log "部署 batocera-wifi / batocera-config / batocera-bluetooth / batocera-resolution 兼容脚本（供 EmulationStation 网络/蓝牙/显示设置使用）"
for name in batocera-wifi batocera-config batocera-bluetooth batocera-resolution; do
    fetch_asset "scripts/$name"
    install -o root -g root -m 0755 "$ASSETS_DIR/scripts/$name" "/usr/local/bin/$name"
done
# ES 以 _ENABLEEMUELEC 编译，isScriptingSupported() 检查的是
# /usr/bin/batocera/<name>（硬编码路径），故须额外部署一份到此处，
# 否则「网络设置」「蓝牙设置」相关菜单不会出现。
mkdir -p /usr/bin/batocera
for name in batocera-wifi batocera-config batocera-bluetooth batocera-resolution; do
    install -o root -g root -m 0755 "$ASSETS_DIR/scripts/$name" "/usr/bin/batocera/$name"
done

log "部署 emuelec-utils 兼容脚本（避免 ES 与游戏切换时跳出 'not found' 错误）"
fetch_asset "scripts/emuelec-utils"
install -o root -g root -m 0755 "$ASSETS_DIR/scripts/emuelec-utils" /usr/bin/emuelec-utils

log "部署 ALSA 软件音量控制配置（启用 ES 音量设置菜单）"
fetch_asset "configs/asound.conf"
# 不同板型 HDMI 音频对应的 ALSA card 编号不同（如 MD1000 是 0、RK3318-Box 是 1），
# 透过 aplay -l 自动侦测，找不到则预设 0
HDMI_CARD="$(aplay -l 2>/dev/null | sed -n 's/^card \([0-9]*\):.*HDMI.*/\1/p' | head -n1)"
HDMI_CARD="${HDMI_CARD:-0}"
log "侦测到 HDMI 音频输出为 card $HDMI_CARD"
sed "s/__CARD__/$HDMI_CARD/g" "$ASSETS_DIR/configs/asound.conf" > /etc/asound.conf
chown root:root /etc/asound.conf
chmod 0644 /etc/asound.conf

log "授予 ping 命令 cap_net_raw 权限（ES 以 game 一般用户检测网络连通性需要用到）"
setcap cap_net_raw+ep /bin/ping 2>/dev/null || setcap cap_net_raw+ep "$(command -v ping)"

ensure_game_user
set_game_password "$GAME_PASSWORD"

log "部署 CPU performance governor 服务（模拟器音效对 CPU 调频延迟敏感，schedutil 动态降频会在音频解码尖峰时断音）"
# RK3566 等 ARM 板默认 schedutil 会随负载动态变频，反应不够快时
# 会饿死模拟器音频线程造成断音/沙沙声（尤其 PSP 的 ATRAC3+ 背景音乐解码）。
# 锁 performance 让各核常驻满频，实测明显改善 PSP 等平台音效稳定度。
cat > /etc/systemd/system/cpu-performance.service <<'EOF'
[Unit]
Description=Set CPU governor to performance (retro gaming)
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do echo performance > "$f"; done'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable cpu-performance.service
systemctl start cpu-performance.service || warn "无法立即套用 performance governor（可能此平台不支持 cpufreq），已设开机自启"

mkdir -p /tmp/es4all-1key

# 仅支援 KMSDRM（非 X11）模式，需要 /dev/dri
if [ -e /dev/dri/card0 ] || [ -e /dev/dri/card1 ]; then
    log "侦测到 /dev/dri，将使用 KMSDRM 模式启动 EmulationStation"
else
    warn "未侦测到 /dev/dri，KMSDRM 模式可能无法正常显示，请确认显示驱动"
fi

log "阶段 1 完成"
