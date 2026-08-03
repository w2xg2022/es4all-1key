#!/bin/bash
# 阶段 7：首次下载机型专属配置（es4all-profiles）
#
# ★为什么安装时就要下载一次，不能等 ES 自己同步★
#   ES 内建的 profiles 客户端(Es4allProfiles)是**背景执行、下次重启 ES 才生效**的，
#   而 mergerfs 那颗二进位、以及聚合脚本 es4all-storage.sh 本身就是由 profiles 下发的 ——
#   等 ES 自己拉的话，第一次开机的「外接挂载」必然是空的（点进去什么也挂不上），
#   使用者只会觉得功能坏了。装机时先拉一次，开机即可用。
#
#   之后的更新仍由 ES 自己做，本阶段只负责「第一份」。两边的落点与 scope 规则相同。
#
# ★本阶段同时取代了旧的阶段 6（手柄键位同步）★
#   键位透传现在【整条来自 profiles】：转换器 common/bin/es-input-to-retroarch.py
#   ＋ 钩子 controls-changed/10-inputconfig.sh，由本阶段一起下发。
#   旧的做法是 1key 自带一份 python 装到 /usr/local/bin，再用 systemd .path 监控
#   es_input.cfg 变更 —— 那会与 profiles 那条**同时**写 autoconfig，而且两份转换器
#   的版本迟早分岔。单一真相比多一条保底重要，故整个移除。
#
# ★scope 规则必须与 ES 客户端一致★(Es4allProfiles.cpp resolveDest)：
#   common/<落点>/…                       rank 0  三个发行版共用
#   armbian/_common/<落点>/…              rank 1  本发行版全机型
#   armbian/<DEVICE>/_common/<落点>/…     rank 2  本晶片家族全机型
#   armbian/<DEVICE>/<SUBDEVICE>/<落点>/… rank 3  单一机型
#   数字大的后套用 => 覆盖前者。
#
#   DEVICE   = /etc/armbian-release 的 BOARDFAMILY，全等比对但**忽略大小写**
#              （仓库写 RK3566、Armbian 写 rk3566，纯全等的话一个档都不会命中）
#   SUBDEVICE= 拿 /proc/device-tree/model 做**子串**比对（model 是一长串描述，
#              不会刚好等于机型键，用全等永远对不上）
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
. ./00-common.sh

require_root
load_config
ensure_game_user

PROFILES_TARBALL="https://codeload.github.com/w2xg2022/es4all-profiles/tar.gz/refs/heads/main"

# 清掉旧版 1key（阶段 6）留下的那条平行路线。★重装到旧机器上必须做★：
# 那个 .path 服务若还 enable 着，就会与 profiles 的钩子同时写 autoconfig，
# 用的还是各自版本的转换器 —— 症状是键位时对时不对，看设定档也查不出原因。
for svc in es-controller-sync.path es-controller-sync.service; do
    if [ -e "/etc/systemd/system/$svc" ]; then
        log "移除旧版的手柄同步服务 $svc（键位透传已改由 profiles 负责）"
        systemctl disable --now "$svc" >/dev/null 2>&1 || true
        rm -f "/etc/systemd/system/$svc"
    fi
done
rm -f /usr/local/bin/es-input-to-retroarch.py
systemctl daemon-reload

GAME_HOME="$(getent passwd "$GAME_USER" | cut -d: -f6)"
WORK="/tmp/es4all-1key/profiles"

log "下载机型专属配置 es4all-profiles"
rm -rf "$WORK"
mkdir -p "$WORK"
if ! curl -fsSL "$PROFILES_TARBALL" -o "$WORK/profiles.tar.gz"; then
    warn "下载 es4all-profiles 失败，略过（ES 启动后会自己再试一次）"
    exit 0
fi
tar -xzf "$WORK/profiles.tar.gz" -C "$WORK"
SRC="$(find "$WORK" -maxdepth 1 -type d -name 'es4all-profiles-*' | head -1)"
if [ -z "$SRC" ]; then
    warn "es4all-profiles 解压后找不到内容，略过"
    exit 0
fi

# ---- 本机的 DEVICE / SUBDEVICE ----
DEVICE="$(sed -n 's/^BOARDFAMILY="\?\([^"]*\)"\?$/\1/p' /etc/armbian-release 2>/dev/null | head -1)"
MODEL="$(tr -d '\000' < /proc/device-tree/model 2>/dev/null || true)"
log "机型判定：DEVICE=${DEVICE:-<空>}  MODEL=${MODEL:-<空>}"

# ★把 ~/.config/emulationstation 做成 ~/.emulationstation 的符号连结★
#
# 为什么非做不可（2026-08-04 查证，否则**键位透传在 A 版整条静默断掉**）：
#   profiles 的落点 token `storage-config` 解析到 ~/.config，于是键位钩子
#   10-inputconfig.sh 落在 ~/.config/emulationstation/scripts/controls-changed/。
#   但 ES 触发钩子时找的是 Paths::getUserEmulationStationPath()/scripts/<event>
#   （Scripting.cpp），而那个路径三个发行版一律是 **$HOME/.emulationstation**。
#   E/R 上 HOME=/storage、两者本来就指向同一处所以对得上；A 版 ~/.emulationstation
#   是 1key 建的**真实目录**，~/.config/emulationstation 根本不存在
#   -> 钩子永远不会被执行，而且没有任何错误讯息：键位精灵照跑、es_input.cfg 照更新，
#      只是 RetroArch 那份 autoconfig 永远停在旧的。
#   连带钩子内部读的 ${ROOT_CFG}/emulationstation/es_input.cfg 也是同一个路径问题。
#
# 一个符号连结同时解决「钩子落点」与「钩子内部读档」两件事，而且是把 A 版对齐成
# 与 E/R 相同的结构 —— 不必改 ES，也不必在 profiles 里放第二份同名档案。
if [ ! -e "$GAME_HOME/.config/emulationstation" ]; then
    log "建立 ~/.config/emulationstation -> ~/.emulationstation 符号连结（键位透传钩子需要）"
    mkdir -p "$GAME_HOME/.config" "$GAME_HOME/.emulationstation"
    ln -s "$GAME_HOME/.emulationstation" "$GAME_HOME/.config/emulationstation"
    chown -h "$GAME_USER:$GAME_USER" "$GAME_HOME/.config/emulationstation"
fi

# 落点 token -> 本机绝对路径。★与 ES 客户端 resolveDestRoot 一一对应★，
# 少解析一个 token 的话，那批档案会被整批当成「不认得的落点」丢掉。
dest_root() {
    case "$1" in
        es-resources)   echo "$GAME_HOME/.emulationstation/resources" ;;
        storage-config) echo "$GAME_HOME/.config" ;;
        bin)            echo "$GAME_HOME/.config/es4all/bin" ;;
        storage)        echo "$GAME_HOME/.emulationstation" ;;
        *)              echo "" ;;
    esac
}

# 把某个 scope 目录整个套用下去。
apply_scope() {
    local scope_dir="$1"
    [ -d "$scope_dir" ] || return 0
    local token
    for token in "$scope_dir"/*; do
        [ -d "$token" ] || continue
        local name root
        name="$(basename "$token")"
        root="$(dest_root "$name")"
        if [ -z "$root" ]; then
            warn "不认得的落点 '$name'，整个目录略过"
            continue
        fi
        mkdir -p "$root"
        # ★不能用 cp -a★（2026-08-04 实机踩过）：上面那个
        # ~/.config/emulationstation -> ~/.emulationstation 符号连结，会让
        # `cp -a storage-config/. ~/.config/` 直接失败：
        #   cp: cannot overwrite non-directory '…/.config/./emulationstation' with directory
        # cp 把「目的地是个符号连结」当成非目录，不肯拿目录盖上去。
        # tar 的 --keep-directory-symlink 正是为这情形而生：遇到指向目录的连结就
        # **穿过它**写进真实目录，而不是把连结换掉。且任何深度都适用，
        # 不必逐层特判（日后再加别的连结也不会重蹈覆辙）。
        tar -C "$token" -cf - . | tar -C "$root" --keep-directory-symlink -xf -
        # ★落在 bin/ 的档要补执行位★：消费端一律用 [ -x ] 判断，
        # 少了执行位会静默走回内建实作，表现是「下发成功但完全没效果」。
        [ "$name" = "bin" ] && chmod -R a+rx "$root" 2>/dev/null || true
        log "套用 $(basename "$(dirname "$scope_dir")")/$(basename "$scope_dir")/$name -> $root"
    done
}

# 在 parent 底下找一个名字与 want 相同（忽略大小写）的目录
find_dir_ci() {
    local parent="$1" want="$2" d
    [ -n "$want" ] || return 0
    for d in "$parent"/*; do
        [ -d "$d" ] || continue
        if [ "$(basename "$d" | tr 'A-Z' 'a-z')" = "$(echo "$want" | tr 'A-Z' 'a-z')" ]; then
            echo "$d"
            return 0
        fi
    done
}

# rank 0 / 1
apply_scope "$SRC/common"
apply_scope "$SRC/armbian/_common"

# rank 2 / 3：先找 DEVICE 层，再在其下找 SUBDEVICE（model 的子串）
DEV_DIR="$(find_dir_ci "$SRC/armbian" "$DEVICE")"
if [ -n "$DEV_DIR" ]; then
    apply_scope "$DEV_DIR/_common"
    if [ -n "$MODEL" ]; then
        for sub in "$DEV_DIR"/*; do
            [ -d "$sub" ] || continue
            subname="$(basename "$sub")"
            [ "$subname" = "_common" ] && continue
            case "$MODEL" in
                *"$subname"*) apply_scope "$sub" ;;
            esac
        done
    fi
else
    warn "仓库里没有对应 DEVICE=${DEVICE:-<空>} 的目录，只套用了通用层"
fi

chown -R "$GAME_USER:$GAME_USER" "$GAME_HOME/.config" "$GAME_HOME/.emulationstation" 2>/dev/null || true

# ---- 跑一次 apply.sh（一次性设定的通用入口）----
# ES 每次启动、同步之后也会呼叫它；这里先跑一次，让首次开机就是设定好的状态。
# 以 $GAME_USER 身分跑：它写的是使用者自己的设定档，用 root 跑会把档案的拥有者弄成 root。
APPLY="$GAME_HOME/.config/es4all/bin/apply.sh"
if [ -x "$APPLY" ]; then
    log "执行 profile 套用钩子 apply.sh"
    su -s /bin/bash "$GAME_USER" -c "HOME='$GAME_HOME' '$APPLY'" || warn "apply.sh 执行失败（不影响安装）"
fi

log "阶段 7 完成"
