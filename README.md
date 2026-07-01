# es4armbian-1key

一键将 Armbian 变身为复古游戏机（搭配 [es4armbian](https://github.com/w2xg2022/es4armbian)）。

## 快速开始

在 Armbian (aarch64) 上以 root 执行：

```bash
curl -fsSL https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main/es4armbian-1key.sh | sudo bash
```

只需这一个文件，其余各阶段脚本与素材会在执行时自动从本仓库下载到 `/tmp/es4armbian-1key/`。

执行时会依次询问以下设定（直接按 Enter 套用预设值即可）：

1. 是否隐藏开机跑码画面（预设：是，套用自定开机图）
2. 要安装的游戏平台（可多选，预设见脚本内 `platforms.sh`）
3. `game` 用户密码（预设：`1234`）
4. 开机/游戏切换时偶尔会闪过几行无害的 ALSA / KMSDRM 错误信息，是否隐藏（预设：是）

完成后执行 `reboot`，开机将自动进入 EmulationStation。

## 测试通过型号

<table>
<thead>
<tr>
<th nowrap>品牌</th><th nowrap>型号</th><th nowrap>芯片</th><th nowrap>RAM+ROM</th><th>Armbian 固件</th>
</tr>
</thead>
<tbody>
<tr>
<td nowrap>浪潮</td><td nowrap>MD1000</td><td nowrap>RK3566</td><td nowrap>2+32</td><td>Armbian_26.05.0_rockchip_md1000_trixie_6.18.33_<br>server_2026.06.01.img.gz</td>
</tr>
<tr>
<td nowrap>贝尔</td><td nowrap>S-010W-AV2B</td><td nowrap>RK3228H</td><td nowrap>1+8</td><td>Armbian_community_26.8.0&#8209;trunk.170_Rk3318&#8209;box_<br>trixie_current_6.18.35_minimal.img.xz</td>
</tr>
</tbody>
</table>

## 各阶段说明

每支脚本皆可单独重跑（idempotent），且会在修改设定前以 `<file>.orig` 备份原始文件，方便还原。

### 阶段 1：环境检测与共用依赖（`01-prep.sh`）
- 安装基础依赖（polkitd/pkexec、SDL2 mixer、NetworkManager、bluez 等），建立 `game` 用户
- 部署 `batocera-wifi`/`batocera-config`/`batocera-bluetooth`/`emuelec-utils` 兼容脚本，使 ES 的网络/蓝牙设置菜单可用并消除游戏切换时的 "not found" 错误信息
- 部署 ALSA 软件音量控制（启用 ES 音量设置菜单），并为 `ping` 赋予 `cap_net_raw` 权限

### 阶段 2：隐藏开机跑码（`02-bootsplash.sh`）
- 修改 `armbianEnv.txt`（`verbosity=0`，并加入 `splash`、`plymouth.ignore-serial-consoles` 等参数）
- 依 `/etc/armbian-release` 自动判断固件来源并套用对应方案：
  - **ophub**（如 MD1000）：`bootlogo=false`，沿用预装的 Plymouth `armbian` 主题，只替换其 `watermark.png`
  - **community**（标准 Armbian，如 RK3318-Box）：`bootlogo=true`，建立自定 `es4armbian` Plymouth 主题（全屏显示 `watermark.png`）
- 重建 initramfs（含 uInitrd 转换），使开机画面在早期阶段即接管画面

### 阶段 3：部署 RetroArch（`03-retroarch.sh`）
- 安装 RetroArch 及所选平台对应 core，套用简体中文界面与 SELECT 组合键热键（即时存档/读档/退出游戏）
- 修正菜单与 OSD 中文字体乱码，`audio_driver` 改为 `alsa`，并启用 Samba 供上传 ROM
- 针对 N64/PSP 等平台套用专属兼容性修正（如 N64 改用 angrylion 软件渲染、PSP 补装 `libopengl0`），避免特定 core 启动崩溃

### 阶段 4：部署 EmulationStation（`04-emulationstation.sh`）
- 安装 EmulationStation 所需的动态库（libvlc 等），从 es4armbian Release 下载并部署到 `/opt/emulationstation`
- 依所选平台生成 `es_systems.cfg`，套用简体中文 `es_settings.cfg`、部署主菜单背景音乐
- 若选择 FC 平台且 ROM 目录为空，预置示范 ROM（240p Test Suite）

### 阶段 5：开机自动启动（`05-autostart.sh`）
- 停用 tty1 的 getty，建立 `es4armbian.service`：以 `game` 用户自动登入 tty1，KMSDRM 模式启动 EmulationStation
- 设定 `Restart=always`（异常退出自动重启）并启用开机自启

### 阶段 6：手柄热键同步（`06-controller-sync.sh`）
- 将 ES「手柄和蓝牙设置」中配置好的手柄按键（`es_input.cfg`）转换为 RetroArch autoconfig，使手柄在 RetroArch / 各游戏核心中可直接使用
- 通过 systemd path 单元监听 `es_input.cfg`，在 ES 中重新设置手柄后自动重新生成配置

## 手柄热键默认值

XBOX 360 / XBOX 360 Compatible 手柄
- SELECT+START：退出游戏
- SELECT+R1（右肩键）：保存即时存档
- SELECT+L1（左肩键）：读取即时存档
- SELECT+X（左侧面键）：呼出 RetroArch 菜单

> 语系透传：进游戏时会自动把 EmulationStation 的界面语言同步给 RetroArch（简中 / 繁中 / 英文等），RetroArch 菜单不再固定英文。

## 手柄按键位置对齐（Remap）

游戏内 ABXY 采用**实体按键位置对齐**而非字母对齐：手柄下方键固定对应 RetroPad B（PS 手柄为叉/✕）、右方键对应 A（圈/○）、左方键对应 X（方块/□）、上方键对应 Y（三角/△），与真实 PlayStation / SNES 等主机手柄的按键位置手感一致。已对所有默认平台生成对应的 RetroArch remap 档案（`~/.config/retroarch/config/remaps/<core>/`），无需逐一手动设置。


## 素材 (`assets/`)

- `watermark.png`：1080p 开机画面（256 色，~556KB），用于 Plymouth armbian 主题
- `configs/asound.conf`：ALSA 软件音量控制设定模板（`01-prep.sh` 部署时自动侦测 HDMI 音频对应的 card 编号并替换，启用 ES 音量设置菜单，`amixer sset PCM <百分比>%` 可调节音量）
- `scripts/batocera-wifi`、`batocera-config`、`batocera-bluetooth`：网络/蓝牙设置兼容脚本（同时部署到 `/usr/local/bin/` 与 `/usr/bin/batocera/`，供 `isScriptingSupported()` 硬编码路径检测）
- `scripts/emuelec-utils`：避免 ES 与 RetroArch 切换时跳出 "not found" 错误信息的兼容脚本
- `scripts/es-input-to-retroarch.py`：将 ES 手柄设定（`es_input.cfg`）转换为 RetroArch autoconfig 的脚本
- `retroarch/retroarch.cfg`：预设简体中文界面、SELECT+R1/SELECT+L1 即时存档与读档、SELECT+START 退出游戏、SELECT+X 呼出菜单、`audio_driver = alsa`
- `fonts/regular.ttf`、`fonts/bold.ttf`：修正 RetroArch xmb 主题菜单与 OSD 中文字体乱码
- `emulationstation/es_systems.cfg`、`es_settings.cfg`：各平台对应 RetroArch core 路径与简体中文预设值
- `music/famicommunist-manifesto.ogg`：ES 主菜单背景音乐（CC0 授权，出自 OpenGameArt Fakebit/Chiptune Music Pack）
- `roms/fc/240pee.nes`、`gamelist.xml`、`media/images/240pee.png`：FC 平台示范 ROM（240p Test Suite v0.23，GNU GPL v2+ 授权）

## 还原

各阶段脚本修改的文件都会留下 `.orig` 备份，例如：

```bash
mv /boot/armbianEnv.txt.orig /boot/armbianEnv.txt
```
