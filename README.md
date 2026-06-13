# es4armbian-1key

一鍵將 Armbian 變身為復古遊戲機（搭配 [es4armbian](https://github.com/w2xg2022/es4armbian)）。

## 快速開始

在 Armbian (aarch64) 上以 root 執行：

```bash
curl -fsSL https://raw.githubusercontent.com/w2xg2022/es4armbian-1key/main/es4armbian-1key.sh | sudo bash
```

只需這一個檔案，其餘各階段腳本與素材會在執行時自動從本倉庫下載到 `/tmp/es4armbian-1key/`。

完成後執行 `reboot`，開機將自動進入 EmulationStation。

## 各階段說明

| 階段 | 腳本 | 內容 |
| --- | --- | --- |
| 1 | `scripts/01-prep.sh` | 安裝共用依賴、建立 `game` 使用者、偵測顯示模式（KMSDRM / X11） |
| 2 | `scripts/02-bootsplash.sh` | 隱藏開機跑碼（`armbianEnv.txt`：`verbosity=0`、`bootlogo=true`），套用自訂 1080p 開機畫面 |
| 3 | `scripts/03-retroarch.sh` | 安裝 RetroArch + NES/SNES core，套用簡體中文設定檔，修正選單中文字體亂碼 |
| 4 | `scripts/04-emulationstation.sh` | 從 es4armbian Release 下載並部署 EmulationStation，套用 `es_systems.cfg` / `es_settings.cfg` |
| 5 | `scripts/05-autostart.sh` | 設定開機自動啟動（KMSDRM 直接啟動 / X11 透過 openbox + systemd） |

每支腳本皆可單獨重跑（idempotent），且會在修改設定前以 `<file>.orig` 備份原始檔，方便還原。

## 素材 (`assets/`)

- `watermark.png`：1080p 開機畫面（256 色，~556KB）
- `retroarch/retroarch.cfg`：預設簡體中文介面、SELECT+START 退出遊戲
- `fonts/regular.ttf`、`fonts/bold.ttf`：修正 RetroArch ozone 主題中文選單亂碼
- `emulationstation/es_systems.cfg`、`es_settings.cfg`：SNES / NES 對應 RetroArch core 路徑

## 還原

各階段腳本修改的檔案都會留下 `.orig` 備份，例如：

```bash
mv /boot/armbianEnv.txt.orig /boot/armbianEnv.txt
```
