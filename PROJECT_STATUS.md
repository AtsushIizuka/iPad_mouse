# PadTrack 開発メモ

最終更新: 2026-04-01

このファイルは、このリポジトリの現状を追記していくための運用メモです。
今後の変更では、機能追加・不具合修正・起動方法の変更があったらこのファイルも更新します。

## 1. 現在の構成

このプロジェクトは、iPad を Mac のトラックパッドとして使うための 2 アプリ構成です。

- `PadTrack`
  - iPad 側アプリ
  - 全画面のタッチ入力を受け取り、Mac にイベントを送る
- `MacPointerHost`
  - Mac 側メニューバー常駐アプリ
  - iPad から来たイベントを受けて、カーソル移動やクリック、スクロール、ジェスチャー近似を実行する
- `SharedCore`
  - 両アプリで共通の入力イベント定義と通信処理を持つ共有層

## 2. ファイルごとの役割

### 共有層

- `Package.swift`
  - `SharedCore` のビルドとテスト定義
- `Sources/SharedCore/InputEvent.swift`
  - iPad と Mac の間で送る入力イベント型
  - ポインタ移動、ボタン、スクロール、ジェスチャーを定義
- `Sources/SharedCore/TransportClient.swift`
  - 通信層の抽象インターフェース
  - 通信状態やエラー文言もここで扱う
- `Sources/SharedCore/PeerTransportClient.swift`
  - `MultipeerConnectivity` を使った実通信実装
  - Bonjour 発見、接続、イベント送信、受信を担当

### iPad 側

- `Apps/PadTrack/PadTrackApp.swift`
  - iPad アプリのエントリーポイント
  - 画面全体の構成、設定シート、接続状態表示を担当
- `Apps/PadTrack/TouchpadSurfaceView.swift`
  - タッチパッド本体の入力面
  - 1 本指、2 本指、3 本指、4 本指の入力判定を担当
- `Apps/PadTrack/TouchpadViewModel.swift`
  - iPad 側の状態管理
  - 感度、ナチュラルスクロール、ジェスチャー設定、イベント送信を担当
- `Apps/PadTrack/Info.plist`
  - iPad 側の権限設定
  - ローカルネットワークと Bonjour 設定を持つ

### Mac 側

- `Apps/MacPointerHost/MacPointerHostApp.swift`
  - Mac アプリのエントリーポイント
  - メニューバー UI、状態表示、権限導線を担当
- `Apps/MacPointerHost/MacHostViewModel.swift`
  - Mac 側の状態管理
  - 接続状態、アクセシビリティ状態、受信イベント表示などを担当
- `Apps/MacPointerHost/PointerController.swift`
  - 実際のマウス移動、クリック、スクロール、ショートカット近似を実行する層
  - 複数ディスプレイ上でのカーソル位置補正もここで担当
- `Apps/MacPointerHost/AccessibilityPermissionManager.swift`
  - アクセシビリティ権限の確認と設定画面を開く処理
- `Apps/MacPointerHost/Info.plist`
  - Mac 側の権限設定
  - メニューバー常駐 (`LSUIElement`) の設定を持つ

### プロジェクト設定

- `project.yml`
  - XcodeGen のプロジェクト定義
- `iPadMouse.xcodeproj`
  - 生成済みの Xcode プロジェクト
- `README.md`
  - セットアップと基本説明

## 3. 現在の機能

### 接続

- `MultipeerConnectivity` で iPad と Mac を自動発見
- 同一ネットワーク上で接続
- iPad 側から再接続可能

### ポインタ操作

- 1 本指ドラッグでカーソル移動
- 1 本指タップで左クリック
- 1 本指ダブルタップでダブルクリック
- 1 本指タップ後ホールドしてドラッグでドラッグ操作
- 2 本指タップで右クリック

### スクロールとジェスチャー

- 2 本指ドラッグでスクロール
- 2 本指左右スワイプで戻る / 進む
- 2 本指ピンチでズーム近似
- 2 本指回転で回転近似
- 2 本指ダブルタップでスマートズーム近似
- 3 本指上 / 下スワイプで Mission Control / App Expose
- 4 本指左右スワイプで Space 切り替え
- 4 本指ピンチで Launchpad / デスクトップ表示

### UI

- iPad 側 UI は日本語化済み
- Mac 側メニュー UI も日本語化済み
- iPad 側は画面全体がタッチパッド面
- 左上ボタンで設定シートを開く

## 4. 起動方法

### Mac 側を起動

普段はこちらを使う:

```bash
open /Users/atsushi/Applications/MacPointerHost.app
```

### Mac 側を再起動

```bash
osascript -e 'tell application "MacPointerHost" to quit'
open /Users/atsushi/Applications/MacPointerHost.app
```

### iPad 側を起動

ホーム画面の `PadTrack` を開くか、必要なら以下を使う:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun devicectl device process launch --device 00008120-001844A13EA00032 com.atsushi.PadTrack
```

### iPad 側を再ビルドしてインストール

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project /Users/atsushi/Desktop/ipad_mouse/iPadMouse.xcodeproj -scheme PadTrack -configuration Debug -destination 'id=00008120-001844A13EA00032' -derivedDataPath /Users/atsushi/Desktop/ipad_mouse/.xcodebuild/DerivedData build install
```

### 共有層テスト

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

## 5. 権限まわり

### iPad 側

- ローカルネットワーク許可が必要
- 初回起動時の許可ダイアログを許可する

### Mac 側

- ローカルネットワーク許可が必要
- アクセシビリティ許可が必要
- アクセシビリティ設定では、`/Users/atsushi/Applications/MacPointerHost.app` を許可対象にする

## 6. 現在の既知の課題

- カーソル移動がまだややカクつくことがある
- 上下方向の移動感がまだ不安定になる場合がある
- スクロール方向は設定値と体感がずれやすく、確認しながら調整中
- 一部のジェスチャーは macOS の公開 API 制約上、ショートカット近似で実装している

## 7. 直近の状態

- iPad と Mac の接続自体は可能
- Mac 側のアクセシビリティ問題は、`/Users/atsushi/Applications/MacPointerHost.app` を許可対象にする方式で安定化
- UI は日本語化済み
- 2 本指スクロール方向は継続調整中
- 体感上の滑らかさ改善は未完了

## 8. 更新ログ

### 2026-04-01

- iPad / Mac の基本接続機能を構築
- Mac 側アクセシビリティ導線を追加
- iPad / Mac の UI を日本語化
- 画面全体タッチパッド化と左上設定ボタン化を実施
- Magic Trackpad 風ジェスチャーを追加
- 複数ディスプレイ移動ロジックを改善
- 現在はスクロール方向と滑らかさを調整中
- 1 本指移動で coalesced touches を使うようにして、細かい中間移動を拾う改善を追加
- Mac 側スクロールに小数リマインダを導入し、小さいスクロール量が消えにくいように改善
