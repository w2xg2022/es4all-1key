#!/bin/bash
# 反安装脚本：撤销 es4all-1key 对系统的更改，尽量还原到安装前状态。
#
# 原则：
#   - 「新建」的档案/服务/主题 → 直接删除
#   - 「修改既有」的档案 → 从安装时留下的 <file>.orig 备份还原
#   - 「状态变更」（服务启停、getty）→ 反向操作
#   - 专属套件（retroarch/samba/libvlc 等）移除；通用套件（bluez/network-manager/
#     plymouth 等系统级）保留，避免牵动其他功能
#   - game 用户与其家目录（含 ROMs、存档）默认「保留」，执行时询问是否删除
set -uo pipefail   # 刻意不用 -e：清理过程要能跨过个别失败继续跑
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh

require_root

GAME_USER="${GAME_USER:-game}"
GAME_HOME="$(getent passwd "$GAME_USER" 2>/dev/null | cut -d: -f6)"
[ -z "$GAME_HOME" ] && GAME_HOME="/home/$GAME_USER"

# 从 /dev/tty 读取输入（支援 curl ... | sudo bash 情境）。
# 注意：/dev/tty 这个装置节点即使在无控制终端时也「存在且权限可读写」，
# 用 [ -r ] 判断会误判为可用 → 之后 read 会报 "No such device or address"。
# 必须实际试着打开它才准。
TTY="/dev/tty"
if ! { : <"$TTY"; } 2>/dev/null; then
    TTY=""
fi
ask() {
    local prompt="$1" default="$2" reply
    if [ -z "$TTY" ]; then echo "$default"; return; fi
    read -r -p "$prompt" reply <"$TTY" >"$TTY" 2>&1 || true
    echo "${reply:-$default}"
}

# 若存在 <file>.orig 则还原并清掉备份；否则视 $2 决定是否删除该档
restore_or_remove() {
    local f="$1" remove_if_no_orig="${2:-no}"
    if [ -e "$f.orig" ]; then
        mv -f "$f.orig" "$f"
        log "还原 $f（自 .orig 备份）"
    elif [ "$remove_if_no_orig" = "yes" ] && [ -e "$f" ]; then
        rm -f "$f"
        log "删除 $f（安装时新建，无 .orig 可还原）"
    fi
}

echo ""
echo "===== es4all-1key 反安装 ====="
echo "将撤销 es4all-1key 的系统更改（服务/脚本/开机画面/Samba 等）。"
echo ""

# ---- 1. 停用并移除 systemd 服务 ----
log "停用并移除 es4all 相关 systemd 服务"
for svc in es4all.service cpu-performance.service es-controller-sync.path es-controller-sync.service; do
    systemctl disable --now "$svc" >/dev/null 2>&1 || true
    rm -f "/etc/systemd/system/$svc"
done

# ---- 2. 还原 tty1 自动登入（安装时 disable 了 getty@tty1）----
log "重新启用 getty@tty1（恢复 tty1 登入终端）"
systemctl enable getty@tty1.service >/dev/null 2>&1 || true

# ---- 3. 删除安装新建的脚本 / shim / 二进制 ----
log "删除相容 shim、启动器与 ES 本体"
rm -f /usr/local/bin/batocera-wifi /usr/local/bin/batocera-config \
      /usr/local/bin/batocera-bluetooth /usr/local/bin/batocera-resolution \
      /usr/local/bin/es4a-ra-launch /usr/local/bin/es-input-to-retroarch.py
rm -f /usr/bin/batocera/batocera-wifi /usr/bin/batocera/batocera-config \
      /usr/bin/batocera/batocera-bluetooth /usr/bin/batocera/batocera-resolution
rmdir /usr/bin/batocera 2>/dev/null || true
rm -f /usr/bin/emuelec-utils
rm -f /etc/tmpfiles.d/es4all.conf
rm -rf /opt/emulationstation

# CPU 调速器权限：tmpfiles 已删，把 sysfs 拥有者立即还原为 root（下次开机也不会再改）
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    [ -e "$f" ] && { chown root:root "$f" 2>/dev/null; chmod 0644 "$f" 2>/dev/null; }
done

# ---- 4. 还原被修改的系统档（从 .orig）----
log "还原被修改的系统设定档"
restore_or_remove /boot/armbianEnv.txt          # verbosity/bootlogo/extraargs
restore_or_remove /etc/samba/smb.conf           # [ROMs] 共享
restore_or_remove /etc/asound.conf yes          # 安装未备份，属新建 → 删除

# ---- 5. 还原开机画面（Plymouth）----
log "还原 Plymouth 开机画面"
# community：安装新建了 es4all 主题并设为默认 → 删除主题，默认切回其他可用主题
if [ -d /usr/share/plymouth/themes/es4all ]; then
    rm -rf /usr/share/plymouth/themes/es4all
    if command -v plymouth-set-default-theme >/dev/null 2>&1; then
        other="$(plymouth-set-default-theme --list 2>/dev/null | grep -vx es4all | head -n1)"
        [ -n "$other" ] && plymouth-set-default-theme -R "$other" >/dev/null 2>&1 || true
    fi
fi
# ophub：安装只替换了 armbian 主题的 watermark.png → 从 .orig 还原
restore_or_remove /usr/share/plymouth/themes/armbian/watermark.png

# 重建 initramfs 让开机画面变更生效（ophub 内核包默认 update_initramfs=no，临时改 yes）
if command -v update-initramfs >/dev/null 2>&1; then
    log "重建 initramfs"
    UIC="/etc/initramfs-tools/update-initramfs.conf"
    if grep -q '^update_initramfs=no' "$UIC" 2>/dev/null; then
        sed -i 's/^update_initramfs=no/update_initramfs=yes/' "$UIC"
        update-initramfs -u -k "$(uname -r)" || true
        sed -i 's/^update_initramfs=yes/update_initramfs=no/' "$UIC"
    else
        update-initramfs -u -k "$(uname -r)" || true
    fi
fi

# ---- 6. Samba：停用共享服务并移除 game 的 smb 帐号 ----
log "移除 Samba 共享设定"
smbpasswd -x "$GAME_USER" >/dev/null 2>&1 || true
systemctl disable --now smbd >/dev/null 2>&1 || true

# ---- 7. 移除专属套件（保留系统通用套件）----
log "移除专属套件（retroarch / samba / libvlc；保留 bluez/network-manager/plymouth 等通用件）"
export DEBIAN_FRONTEND=noninteractive
# 仅移除、不 purge（保留设定）；不 autoremove（避免误删其他功能的依赖）
apt-get remove -y retroarch samba libvlc5 libvlccore9 >/dev/null 2>&1 || \
    warn "部分专属套件移除失败或未安装，可手动检查"

# ---- 8. game 用户与家目录（含 ROMs / 存档）----
if id "$GAME_USER" >/dev/null 2>&1; then
    echo ""
    ans="$(ask "是否连同 $GAME_USER 用户与家目录 $GAME_HOME 一起删除？内含 ROMs 与游戏存档，删除不可复原！[y/N]: " "n")"
    case "$ans" in
        [Yy]*)
            log "删除用户 $GAME_USER 与家目录 $GAME_HOME"
            pkill -u "$GAME_USER" 2>/dev/null || true
            userdel -r "$GAME_USER" 2>/dev/null || warn "userdel 失败，请手动检查 $GAME_HOME"
            ;;
        *)
            log "保留 $GAME_USER 用户与家目录（ROMs/存档、ES 与 RA 设定都留着，可日后重装接续）"
            ;;
    esac
fi

systemctl daemon-reload
rm -rf /tmp/es4all-1key

echo ""
log "反安装完成。建议重启（reboot）让开机画面/终端等更改完全生效。"
echo ""
echo "说明（这些刻意不动，避免误伤系统）："
echo "  - 时区仍为 Asia/Shanghai（安装时设定，无法得知原值；如需改回请自行 timedatectl set-timezone）"
echo "  - 系统语系 locale 未被安装更改，无需还原"
echo "  - 通用套件（bluez / network-manager / plymouth / polkit / fontconfig 等）保留"
echo "  - ping 的 cap_net_raw 权限保留（无害）"
