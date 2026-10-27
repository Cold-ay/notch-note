# NotchAgenda iOS 建置與發佈

支援 iOS／iPadOS 17 以上，包含 App 與小／中型主畫面 Widget。原生 Mac 的瀏海入口僅在 macOS 提供。

## 1. 開發環境

需要完整 Xcode、iOS SDK、至少一個 iOS Simulator runtime，以及 XcodeGen。安裝 Xcode 後先開啟一次、完成元件安裝；可透過 `brew install xcodegen` 安裝產生工具。

```sh
./scripts/build-ios.sh --simulator
./scripts/build-ios.sh --test
```

腳本預設使用 `/Applications/Xcode.app/Contents/Developer`；可用 DEVELOPER_DIR 指定其他 Xcode。測試預設挑選第一個可用 iPhone 模擬器，亦可設置 IOS_SIMULATOR_ID。產生的 NotchAgenda.xcodeproj 可直接用 Xcode 開啟，選 NotchAgenda-iOS scheme。

輸出：

- `.build/ios/Build/Products/Debug-iphonesimulator/NotchAgenda.app`
- `.build/distribution/NotchAgenda-simulator.zip`：僅供模擬器，不能安裝到實體 iPhone。
- `.build/test-results/*.xcresult`：單元／UI 測試結果，可用 Xcode 開啟。

安裝至已啟動模擬器：

```sh
xcrun simctl install booted .build/ios/Build/Products/Debug-iphonesimulator/NotchAgenda.app
xcrun simctl launch booted com.colday.notchagenda
```

`simctl` 亦需使用完整 Xcode 的 developer directory。

## 2. 未有 Apple Developer 帳戶

仍可完成模擬器測試與真機 arm64 的 Release 編譯：

```sh
./scripts/build-ios.sh --unsigned-archive
```

產物 `.build/distribution/NotchAgenda-unsigned.xcarchive` 是**未簽署封存**，驗證正式裝置架構可建置，不能當作可下載安裝的 IPA，亦不能直接上載 TestFlight。不要把模擬器 App 壓成 IPA 假裝真機安裝包。

使用個人免費 Apple ID 的 Xcode 裝置開發與付費 TestFlight 發佈不同；此 App 的共用 App Group 能力仍需相應 provisioning 支援。建議保留現有 App／Widget 設計，待有付費開發者帳戶後正式簽署。

## 3. 日後製作可下載版本

1. 加入 Apple Developer Program，在 Xcode Settings → Accounts 登入。建立可用的 Apple Development／Apple Distribution 簽署及 provisioning profile。
2. 在開發者後台註冊 App ID `com.colday.notchagenda`、Widget ID `com.colday.notchagenda.widget`、App Group `group.com.colday.notchagenda`，讓兩個 App ID 都啟用同一個群組。若識別碼被佔用，需一致修改 project.yml 及 TaskStore.storageURL 的群組名稱。
3. 在 App Store Connect 建立 NotchAgenda，選相同 App ID；準備支援網址、隱私政策、介紹、年齡分級及 iPhone／iPad 截圖。
4. 對兩個 target 設定相同 Team，確認自動簽署能取得 profile。每次上載前提高 project.yml 的 CURRENT_PROJECT_VERSION。
5. 設定 Team ID 並封存／匯出：

```sh
export APPLE_TEAM_ID=YOUR_TEAM_ID
./scripts/build-ios.sh --archive
./scripts/build-ios.sh --export
```

簽署封存位於 `.build/distribution/NotchAgenda.xcarchive`；匯出位於 `.build/distribution/AppStore/`。命令只封存／匯出，不自動上載或公開發佈。若尚無 profile，可先在 Xcode 選 Team 並建置一次，由 Xcode 處理帳戶所需設定。

6. 在 Xcode Organizer 選簽署封存，執行 Distribute App → App Store Connect → Upload；亦可將匯出 IPA 透過 Apple Transporter 上載。
7. 等待 Apple 處理完成，在 TestFlight 加入內部測試者。外部測試依 Apple 的 Beta App Review 流程審核，完成後才開啟公開測試連結。正式 App Store 上架另需提交審核。

Apple 文件：[發佈測試與正式版本](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases)、[TestFlight 發佈](https://help.apple.com/xcode/mac/current/en.lproj/dev2539d985f.html)。編譯／自動化測試通過並不代表 Apple 審核通過。

## 4. 功能、資料與隱私

App 提供日／週／月／無期限／日曆分頁、批量輸入、右滑完成、左滑移到隊尾、完成清單、重複事項、可還原垃圾桶、日記與三語／外觀設定。Widget 顯示當期未完成事項及目標，點擊後進 App 操作。

iOS App 與 Widget 共用 `group.com.colday.notchagenda` 容器的 tasks.json、journal.json、preferences.json。實際路徑由系統配置，每次安裝可能不同。它與 Mac 的 `~/Library/Application Support/FlowTasks/` 分開，不會自動同步。舊 `com.example.flowtasks` iOS 原型是另一個 App／群組，正式身分不會自動搬移其資料。

沒有帳戶、廣告 SDK、分析 SDK 或網路後端；使用者文字存在本機，沒有額外的 App 層加密。Resources/PrivacyInfo.xcprivacy 宣告不追蹤、不收集資料，UserDefaults 僅供本機 App 功能。發佈時仍需在 App Store Connect 填寫與實際功能一致的 App Privacy 回答及可公開存取的隱私政策網址。

## 5. 發佈前人工檢查

- 在實體 iPhone／iPad 驗證鍵盤、不同字體大小、橫直向及長清單。
- 加入小／中 Widget，驗證完成後更新、每日切換及未來事項不提前顯示。更新時間由 iOS 控制。
- 用簽署版測試重啟、背景保存、垃圾桶還原及 App Group 權限。
- 確認三語、四款外表、四款內頁與深色語言選擇可讀，日記及未送出草稿不因換外觀而消失。
- 確認所有素材、metadata、隱私政策及 Apple 帳戶協議準備妥當，再提交審核。
