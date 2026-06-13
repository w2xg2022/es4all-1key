# README 待补充事项

> 注意：README 应改写为简体中文（含脚本输出风格）。

- [x] make_es23：「用户界面设置」退出泛白闪烁问题已修复（`Window.cpp` 增加
  `bottom == top` 时 `resetMenuBackgroundShader()`），已写入 es4armbian 仓库 README。
- [ ] 整体品牌从「EMUELEC」过渡为 es4armbian / Armbian 命名（持续推进中，
  目前 1key 与 ES 端 README 已基本不再出现 EMUELEC，部分内部兼容脚本/文件名
  仍保留 emuelec 命名以维持向后兼容，视情况逐步处理）
- [ ] 说明 ES 的"网络设置"菜单中"主机名称"现在会读取系统真实 hostname（如 armbian → 显示为 ARMBIAN），
  不再硬编码为 "EMUELEC"（来自 SystemConf.cpp 的源码修改，需 make_es24 编译生效）
- [ ] 补充"过场画面设置"(原 SPLASH SETTINGS) 菜单的中文翻译修订说明，统一"开机画面/退出画面"用词
  （翻译方案已确认，待 make_es24 编译时套用到 zh_CN + zh_TW 的 .po）
