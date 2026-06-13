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
  （已排查：asound.conf 中 `card 0` 写法本身无误，多次手动复现测试
  amixer/aplay/speaker-test/retroarch 均无法重现；推测是该机型 HDMI 音效
  绑定在 HDMI 显示输出上，ES↔RetroArch 切换瞬间 KMSDRM 重新协商显示模式时
  `/proc/asound/cards` 短暂消失导致的硬件时序竞态，属于无害的瞬间讯息）
- [x] 安装互动问答新增第 4 项：「游戏切换时偶尔会闪过一行 ALSA 错误讯息（无害），
  是否隐藏？[Y/n]」，默认 Y。选 Y 时，`es4armbian.service` 的 `ExecStart` 改为
  `/bin/bash -c 'exec /opt/emulationstation/emulationstation 2> >(grep -v --line-buffered "ALSA lib" >&2)'`，
  仅过滤含 "ALSA lib" 字串的 stderr 行（RetroArch 作为子进程继承同一 fd，
  也会被一并过滤），不影响其他错误讯息的可见性
- [ ] 说明 RetroArch `audio_driver` 已从默认的 `pulse`（无 PulseAudio，导致游戏内无声音）
  改为 `alsa`
- [ ] （待 make_es23 一并处理）「用户界面设置」退出问题：经实机录屏复现，
  退出"用户界面设置"返回主菜单时（约 0.5 秒内），背景截图会短暂"变亮/泛白"
  再恢复正常；退出其他子菜单（如平台设置等）不会出现。已排除 `reloadAll`
  逻辑问题（源码本身已有"仅设置变更才 reload"的判断）与 ping 报错问题
  （已另行修复，见下方 setcap 条目）。推测是 `GuiSettings`/`MenuComponent`
  关闭动画时背景"变暗遮罩(dim overlay)"透明度短暂跳变导致一两帧过曝，
  需查看 `es-app/src/guis/GuiSettings.cpp` 与 `MenuComponent` 的 dim/opacity
  收尾动画逻辑，编译新版二进位后在 MD1000 上反复录屏验证
- [x] 说明 `01-prep.sh` 新增 `setcap cap_net_raw+ep /bin/ping`：
  根因排查发现 ES 在开机/ES↔RetroArch 切换时会以 `ping -c 1 ... 223.5.5.5/8.8.8.8` 等
  侦测网络连通性（ApiSystem.cpp updateNetworkStatus），但 `game` 一般用户的 `ping`
  缺少 `cap_net_raw` 权限，导致 `ping: socket: Operation not permitted /
  missing cap_net_raw+p capability or setuid?` 错误讯息直接打印到 HDMI 画面
  （因 ExecStart 以 `StandardOutput=tty` 跑），看起来像画面被"刷新/闪烁"。
  设定 `setcap cap_net_raw+ep /bin/ping` 后，`game` 用户可正常 ping，不再有
  该错误讯息污染画面（已在 MD1000 上验证）
- [x] 说明 `04-emulationstation.sh` 新增：部署 ES 主菜单背景音乐（BGM），
  使用 CC0 授权曲目 "Famicommunist Manifesto"（出自 OpenGameArt 的
  Fakebit/Chiptune Music Pack，作者声明 CC0、可自由使用），
  放在 `~/.emulationstation/music/`（首次安装时若该目录为空才放入，
  不覆盖使用者自行加入的音乐）；素材位于 `assets/music/famicommunist-manifesto.ogg`
- [x] 说明 `04-emulationstation.sh` 新增：若选择安装 FC 平台且 ROM 目录为空，
  会自动放入示范 ROM `240pee.nes`（240p Test Suite v0.23，作者 Damian Yerrick / pinobatch，
  GNU GPL v2+ 授权，可自由使用），并附带 `gamelist.xml`（含简介文字）与截图，
  让使用者首次开机时即使尚未上传 ROM，也能进入游戏列表查看与测试画面/控制器
  （素材位于 `assets/roms/fc/`：`240pee.nes`、`gamelist.xml`、`media/images/240pee.png`）
- [x] 新增阶段 `06-controller-sync.sh`：将 ES「控制器和蓝牙设置」中设定好的
  手柄按键映射（`~/.emulationstation/es_input.cfg`）自动转换为 RetroArch
  autoconfig 设定档（`~/.config/retroarch/autoconfig/<手柄名>.cfg`），
  使用者在 ES 中配置好的手柄可直接在 RetroArch / 各游戏核心中使用，
  不会再出现 "xxx pad (vendor/product) not configured" 警告，也不需要
  在 RetroArch 里重新设置一次按键
  - 转换脚本：`assets/scripts/es-input-to-retroarch.py`
    （部署到 `/usr/local/bin/es-input-to-retroarch.py`），支援按钮、
    摇杆轴（含正负号）、D-Pad（hat 或按钮形式）与 hotkey 按键的映射，
    并从 `deviceGUID` 解析出 `input_vendor_id` / `input_product_id`
  - 安装时若已存在 `es_input.cfg` 会立即同步一次
  - 透过 systemd path 单元 `es-controller-sync.path`（监控
    `es_input.cfg` 的 `PathModified`）与对应的
    `es-controller-sync.service`，使用者每次在 ES 中重新设置手柄后，
    会自动重新生成 autoconfig，无需手动操作
  - 已在 MD1000 上验证：实际 Xbox 360 Controller 的 es_input.cfg
    被正确转换（vendor_id=1118, product_id=654，各按键/摇杆/D-Pad/
    hotkey 映射均正确），且修改 es_input.cfg 后会自动触发重新生成
