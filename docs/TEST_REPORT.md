# NotchAgenda 0.9.0 測試紀錄

日期：2026-10-27。建置版本：10。工具：Xcode 26.6，iOS SDK／Simulator 26.5。

| 檢查 | 結果 |
| --- | --- |
| macOS Swift 套件測試 | 56 項通過，0 失敗 |
| iOS 共用模型／偏好／日記／Widget 查詢測試 | 32 項通過，0 失敗 |
| iPhone 17 Pro、iOS 26.5 介面流程 | 3 項通過，0 失敗 |
| App＋Widget 模擬器建置 | 通過，已產生 ZIP |
| iOS arm64 Release 未簽署封存 | 通過 |
| App／Widget 版本一致 | 兩者皆 0.9.0（10） |
| macOS App 打包 | 通過 |
| 格式、設定及語系鍵檢查 | git diff --check、腳本語法、plist 解碼通過；新增 UI 英文對照齊全 |

介面測試實際執行：

1. 每行一件批量輸入 → 完成 → 已完成清單 → 移回待辦 → 刪除 → 垃圾桶還原 → 重啟確認保留。
2. 切換 English、粉色外表、點陣內頁 → 寫日記 → 等待自動保存 → 重啟確認日記及設定保留。
3. 每天重複的 Duolingo → 今天完成後移出待辦 → 下一天重新出現 → 回到今天仍保持完成。

深色語言選擇已以 Mac 原生畫面及 iPhone 測試截圖檢查；Mac 使用 dark Aqua 原生選單，避免淺色模式把選項文字壓暗。

Widget 測試涵蓋未來事項不提前顯示、已刪除／已完成排除、重複事項下一期出現及讀檔後一致。

重跑方式：

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --disable-sandbox
./scripts/build-ios.sh --test
./scripts/build-ios.sh --simulator
./scripts/build-ios.sh --unsigned-archive
```

iOS 結果位於本機 `.build/test-results/ios-20261027-165040.xcresult`，包含保留的語言設定截圖。最終封存與模擬器 ZIP 位於 `.build/distribution/`，不提交編譯產物到 Git。

第一次介面測試發現重名的 Done 按鈕，已改用固定 accessibility ID；其後一次模擬器因 Busy 無法啟動，改用全新獨立 QA 裝置後完整重跑通過。

尚未進行：Apple Developer 簽署、實體 iPhone／iPad 測試、簽署版 App Group／Widget 實機驗證、TestFlight 上載或 Apple App Review。未簽署封存和模擬器 ZIP 不能直接安裝到一般 iPhone。此紀錄是開發測試結果，不代表 Apple 審核通過。
