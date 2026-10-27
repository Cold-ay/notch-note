# NotchAgenda

原生 macOS 瀏海／頂部待辦日記。滑鼠停在螢幕頂部中央即可展開；待辦、目標與文字日記放在同一個浮動面板。

- 瀏海及無瀏海螢幕的 hover 入口，支援多螢幕、釘選與 Esc 收起。
- 每日事項、週目標、月目標、無期限待辦與未來日期安排。
- 每日／每週／每月重複事項，各期完成狀態獨立。
- 完成後移入「已完成」，可移回待辦；不累積重新開始的日誌。
- 可還原的垃圾桶，以及每日／每週／每月文字日記、自動儲存。

## 啟動

需要 macOS 14+、支援 Swift 6 的完整 Xcode。先結束舊版 FlowTasks／NotchAgenda，再執行：

```sh
git clone https://github.com/Cold-ay/notchagenda.git
cd notchagenda
./scripts/run-mac.sh
```

首次啟動後，主視窗會收起，選單列及頂部黑色入口會保留。把滑鼠停在瀏海或頂部中央約 0.24 秒，即可展開；亦可從選單列或 Dock 開啟主視窗。

建置產物：`.build/NotchAgenda.app`。只建置、不啟動：

```sh
./scripts/run-mac.sh --build-only
```

## 文件

- [使用指南](docs/USER_GUIDE.md)：操作流程、hover、完成／刪除、日記、資料位置、備份還原與疑難排解。
- [開發指南](docs/DEVELOPMENT.md)：架構、功能與檔案對照、資料格式、hover 狀態機、測試，以及如何擴充各功能。

## 資料位置與改名相容

為沿用舊版資料，Mac 正式版刻意保留既有儲存目錄：

```text
~/Library/Application Support/FlowTasks/
├── tasks.json
└── journal.json
```

App 名稱、Swift module、source/test 目錄及 bundle 已改為 NotchAgenda；資料不會因改名另建空白清單。首次使用前請結束舊版，避免兩個程序同時寫入。

## 測試與 QA

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/run-mac.sh --qa
```

QA App 使用不同 bundle identifier，資料存於 `.build/qa/`，不使用正式資料。核心流程、原生輸入／勾選整合、資料相容、hover 延遲及螢幕幾何均有測試。

目前主要支援 Mac。iPhone 與 Widget 保留原型，尚未配套全部新介面；未提供 iCloud 同步、通知或 Apple Calendar 整合。此建置腳本用於本機開發，尚未包含 Developer ID 簽署與公證流程。
