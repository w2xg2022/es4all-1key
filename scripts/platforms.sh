# 平台定义表：新增平台时只需在这里加一行对应的设定
# core 档案直接从 libretro buildbot (aarch64 nightly) 下载，避免 apt 套件名称/版本不一致问题
CORE_BUILDBOT_BASE="https://buildbot.libretro.com/nightly/linux/aarch64/latest"

PLATFORM_CODES=(fc sfc md gba ps1 mame fbneo dos dc apple2 n64 psp gbc saturn pce)

declare -A PLATFORM_NAME=(
    [fc]="FC / 红白机 (Nintendo)"
    [sfc]="SFC / 超级任天堂 (Super Nintendo)"
    [md]="MD / 世嘉 (Sega Genesis)"
    [gba]="GBA (Game Boy Advance)"
    [ps1]="PS1 (PlayStation)"
    [mame]="MAME (街机, mame2003-plus)"
    [fbneo]="FBNeo (街机/Neo Geo)"
    [dos]="DOS (经典电脑游戏)"
    [dc]="DC / 世嘉 (Sega Dreamcast) [需自编 GLES flycast，见下方说明]"
    [apple2]="Apple II (苹果二代)"
    [n64]="N64 (Nintendo 64)"
    [psp]="PSP (PlayStation Portable)"
    [gbc]="GBC (Game Boy Color)"
    [saturn]="Saturn (世嘉土星)"
    [pce]="PCE (PC Engine / TurboGrafx-16)"
)

declare -A PLATFORM_CORE=(
    [fc]="nestopia_libretro.so"
    [sfc]="snes9x_libretro.so"
    [md]="genesis_plus_gx_libretro.so"
    [gba]="mgba_libretro.so"
    [ps1]="pcsx_rearmed_libretro.so"
    [mame]="mame2003_plus_libretro.so"
    [fbneo]="fbneo_libretro.so"
    [dos]="dosbox_pure_libretro.so"
    [dc]="flycast_libretro.so"
    [apple2]="applewin_libretro.so"
    [n64]="parallel_n64_libretro.so"
    [psp]="ppsspp_libretro.so"
    [gbc]="mgba_libretro.so"
    [saturn]="yabause_libretro.so"
    [pce]="mednafen_pce_fast_libretro.so"
)

declare -A PLATFORM_EXT=(
    [fc]=".nes .NES .zip .ZIP"
    [sfc]=".smc .sfc .SMC .SFC .zip .ZIP"
    [md]=".md .bin .gen .MD .BIN .GEN .zip .ZIP"
    [gba]=".gba .GBA .zip .ZIP"
    [ps1]=".bin .cue .pbp .chd .BIN .CUE .PBP .CHD"
    [mame]=".zip .ZIP"
    [fbneo]=".zip .ZIP"
    [dos]=".conf .bat .exe .iso .cue .m3u .zip .CONF .BAT .EXE .ISO .CUE .M3U .ZIP"
    [dc]=".chd .gdi .cdi .m3u .zip .CHD .GDI .CDI .M3U .ZIP"
    [apple2]=".dsk .do .po .nib .zip .DSK .DO .PO .NIB .ZIP"
    [n64]=".z64 .n64 .v64 .zip .Z64 .N64 .V64 .ZIP"
    [psp]=".iso .cso .pbp .ISO .CSO .PBP"
    [gbc]=".gbc .gb .zip .GBC .GB .ZIP"
    [saturn]=".cue .chd .iso .zip .CUE .CHD .ISO .ZIP"
    [pce]=".pce .cue .ccd .chd .toc .m3u .zip .PCE .CUE .CCD .CHD .TOC .M3U .ZIP"
)

declare -A PLATFORM_ESNAME=(
    [fc]="nes"
    [sfc]="snes"
    [md]="genesis"
    [gba]="gba"
    [ps1]="psx"
    [mame]="mame"
    [fbneo]="fbneo"
    [dos]="pc"
    [dc]="dreamcast"
    [apple2]="apple2"
    [n64]="n64"
    [psp]="psp"
    [gbc]="gbc"
    [saturn]="saturn"
    [pce]="pcengine"
)

declare -A PLATFORM_FULLNAME=(
    [fc]="Nintendo Entertainment System"
    [sfc]="Super Nintendo Entertainment System"
    [md]="Sega Genesis / Mega Drive"
    [gba]="Game Boy Advance"
    [ps1]="Sony PlayStation"
    [mame]="Arcade (MAME)"
    [fbneo]="Arcade (FinalBurn Neo)"
    [dos]="MS-DOS"
    [dc]="Sega Dreamcast"
    [apple2]="Apple II"
    [n64]="Nintendo 64"
    [psp]="Sony PSP"
    [gbc]="Game Boy Color"
    [saturn]="Sega Saturn"
    [pce]="PC Engine / TurboGrafx-16"
)

declare -A PLATFORM_ROMDIR=(
    [fc]="nes"
    [sfc]="snes"
    [md]="genesis"
    [gba]="gba"
    [ps1]="psx"
    [mame]="mame"
    [fbneo]="fbneo"
    [dos]="pc"
    [dc]="dreamcast"
    [apple2]="apple2"
    [n64]="n64"
    [psp]="psp"
    [gbc]="gbc"
    [saturn]="saturn"
    [pce]="pcengine"
)

# es-theme-alekfull-EmueELEC 主题目录名与 PLATFORM_ESNAME 不一致的平台，
# 未列出的平台沿用 PLATFORM_ESNAME 作为主题目录名
declare -A PLATFORM_THEME=(
    [fbneo]="fbn"
)

# libretro core 的 remap 目录名。RA 找 per-core remap 时用的是核心 *运行时 library_name*，
# 不是 .info 里的 corename——两者多半相同，但 applewin 例外（.info=小写 "applewin"，
# library_name="AppleWin"），填错大小写 RA 会找不到而退回标签对齐 → 键位乱。
# 下表已全部填 library_name（apple2=AppleWin），对应目录：
#   ~/.config/retroarch/config/remaps/<library_name>/<library_name>.rmp
declare -A PLATFORM_CORENAME=(
    [fc]="Nestopia"
    [sfc]="Snes9x"
    [md]="Genesis Plus GX"
    [gba]="mGBA"
    [ps1]="PCSX-ReARMed"
    [mame]="MAME 2003-Plus"
    [fbneo]="FinalBurn Neo"
    [dos]="DOSBox-pure"
    [dc]="Flycast"
    [apple2]="AppleWin"
    [n64]="ParaLLEl N64"
    [psp]="PPSSPP"
    [gbc]="mGBA"
    [saturn]="Yabause"
    [pce]="Beetle PCE Fast"
)

# 默认安装的 14 个平台（已在 MD1000 上逐一验证可正常进入游戏）。
# dc（Dreamcast/flycast）不在默认列表——2026-07-12 MD1000(RK3566) 实测确认：
# libretro buildbot 的 flycast core 虽内含 GLES 着色器，但其 retro_get_preferred_hw_render
# 默认请求 *桌面 OpenGL* 上下文，被 Debian GLES-only 编译的 RetroArch 直接拒绝：
#   "Requesting OpenGL context, but RetroArch is compiled against OpenGLES. Cannot use HW context."
# 核心无 GL/GLES renderer 切换选项；Vulkan 路径也无（板子无 Vulkan ICD）。
# 唯一解=自编 USE_GLES=ON 的 flycast core（让其请求 GLES 上下文）。待编译验证后再纳入。
DEFAULT_PLATFORMS="fc sfc md gba ps1 mame fbneo dos apple2 n64 psp gbc saturn pce"
