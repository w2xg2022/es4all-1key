# README 待补充事项（暂不编辑 README，先记录）

> 注意：README 应改写为简体中文（含脚本输出风格），但本轮不动 README，仅记录待办。

- [ ] 整体品牌从「EMUELEC」过渡为 es4armbian / Armbian 命名
- [ ] 说明 `01-prep.sh` 现在会安装 `bluez`，并部署以下兼容脚本：
  - `/usr/local/bin/batocera-wifi`、`batocera-config`、`batocera-bluetooth`
  - 同时复制到 `/usr/bin/batocera/`（因 ES 以 `_ENABLEEMUELEC` 编译，`isScriptingSupported()` 硬编码检查该路径，否则"网络设置""控制器和蓝牙设置"菜单不会出现）
  - `/usr/bin/emuelec-utils` 兼容 shim（避免 ES 与 RetroArch 切换时屏幕跳出 "not found" 错误代码）
- [ ] 说明 `01-prep.sh` 会部署 `/etc/asound.conf`（ALSA softvol 虚拟 "PCM" 混音控件），
  使 ES 的"音量设置"菜单（系统音量/音乐音量/音量提示开关）可用，且 `amixer -c0 sset PCM <百分比>%` 可调节音量
- [ ] 说明 `03-retroarch.sh` 现在会同步设置 `xmb_font` 与 `video_font_path` 为内置中文字体，
  解决 RetroArch 菜单/OSD 中文显示为方块（乱码）的问题
- [ ] 说明 ES 的"网络设置"菜单中"主机名称"现在会读取系统真实 hostname（如 armbian → 显示为 ARMBIAN），
  不再硬编码为 "EMUELEC"（来自 SystemConf.cpp 的源码修改，需 make_es24 编译生效）
- [ ] 补充"过场画面设置"(原 SPLASH SETTINGS) 菜单的中文翻译修订说明，统一"开机画面/退出画面"用词
  （翻译方案已确认，待 make_es24 编译时套用到 zh_CN + zh_TW 的 .po）
- [ ] 说明 `01-prep.sh` 新增安装 `alsa-ucm-conf`，消除 `alsa-restore.service` 在开机时
  因找不到 UCM 配置而报错（"Cannot get card index for 0" 等 ALSA 警告）
- [x] 说明 `02-bootsplash.sh` 的开机图方案（已验证成功）：
  - 该内核未编译 CONFIG_BOOTSPLASH，ophub 自带开机图（bootlogo=true）机制无效，故维持 bootlogo=false
  - 改用 Plymouth：extraargs 加入 `splash`，套用自定 armbian 主题 watermark.png
  - **关键坑点**：必须同时加入 `plymouth.ignore-serial-consoles`，否则 Plymouth 侵测到
    `console=ttyS2,...` 序列埠主控台存在，会强制使用纯文字 details 外挂，自定图完全不显示
  - **关键坑点 2**：Armbian 的内核包默认 `update_initramfs=no`，导致 `update-initramfs -u`
    被跳过、不会触发 Armbian 专属的 `initrd.img -> uInitrd` 转换（u-boot 实际读取的是
    `/boot/uInitrd`），脚本须临时改为 `yes` 再执行再还原
  - 已实测确认开机时会显示自定图（街机大厅插画）
- [x] "小代码"（开机/切换时跑码）问题：根因是 fbcon 在 DRM 装置注册瞬间把缓冲的核心讯息
  整批显示到画面上；加入 `plymouth.ignore-serial-consoles` 让 Plymouth 正确接管画面后，
  此问题大幅改善（不再整面跑码），但 ES↔RetroArch 切换瞬间仍可能闪过单行
  `ALSA lib confmisc.c:165:(snd_config_get_card) Cannot get card index for 0` 错误讯息
  （独立的小问题，与 asound.conf 的 card 0 设置有关，尚待修复）
- [ ] 说明 RetroArch `audio_driver` 已从默认的 `pulse`（无 PulseAudio，导致游戏内无声音）
  改为 `alsa`
