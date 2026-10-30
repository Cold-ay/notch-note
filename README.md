# NotchAgenda

原生 macOS 與 iOS 待辦日記。Mac 滑鼠停在螢幕頂部中央即可展開；待辦、目標與文字日記放在同一個浮動面板。

- 有瀏海時貼合裝置相機區；無瀏海保留膠囊入口。Hover 緩緩下滑展開、向上收回，可在收回途中接續展開；支援多螢幕、釘選與 Esc。
- 設定支援繁體中文、简体中文、English；保留原本橫向分頁，另可自由配搭米白／粉色／沉穩大叔／極簡線條外表與橫線／方格／點陣／空白內頁。
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

- [Privacy Policy / 私隱政策](https://cold-ay.github.io/notchagenda/privacy.html)：本機資料、保存／刪除及支援方式。

- [使用指南](docs/USER_GUIDE.md)：操作流程、hover、完成／刪除、日記、資料位置、備份還原與疑難排解。
- [開發指南](docs/DEVELOPMENT.md)：架構、功能與檔案對照、資料格式、hover 狀態機、測試，以及如何擴充各功能。

## 資料位置與改名相容

為沿用舊版資料，Mac 正式版刻意保留既有儲存目錄：

```text
~/Library/Application Support/FlowTasks/
├── tasks.json
├── journal.json
└── preferences.json
```

App 名稱、Swift module、source/test 目錄及 bundle 已改為 NotchAgenda；資料不會因改名另建空白清單。首次使用前請結束舊版，避免兩個程序同時寫入。

## 測試與 QA

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
./scripts/run-mac.sh --qa
```

QA App 使用不同 bundle identifier，資料存於 `.build/qa/`，不使用正式資料。核心流程、原生輸入／勾選整合、資料相容、hover 延遲及螢幕幾何均有測試。

支援 macOS 14+、iOS/iPadOS 17+。iOS 提供五個功能頁、完成清單、滑動完成／移到隊尾、重複事項、日記、可還原垃圾桶、三語與外觀設定，以及主畫面 Widget。未提供 iCloud 同步、通知或 Apple Calendar 整合；Mac 與 iPhone 資料各自存在本機。Mac 建置尚未包含 Developer ID 簽署與公證。

## iPhone / iPad 建置

安裝 Xcode、iOS Simulator runtime 與 XcodeGen（`brew install xcodegen`），再執行：

```sh
./scripts/build-ios.sh --simulator        # 模擬器 App 與 ZIP
./scripts/build-ios.sh --test             # iPhone 單元／介面測試
./scripts/build-ios.sh --unsigned-archive # 真機架構 Release 封存驗證，不能安裝到 iPhone
```

模擬器 ZIP 及未簽署封存供開發驗證，不能作為一般 iPhone 下載包。加入 Apple Developer Program 並設定 Team／簽署後，可用 `--archive`／`--export`，再透過 TestFlight 或 App Store 提供下載。
