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
  - 感度、加速度カーブ、ナチュラルスクロール、ジェスチャー設定、イベント送信を担当
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
- `docs/SETUP_ON_ANOTHER_MAC.md`
  - 他の Mac 向けの英語セットアップ手順
- `scripts/bootstrap.sh`
  - 初回セットアップ、XcodeGen 実行、共有テスト、Xcode 起動
- `scripts/set_team.sh`
  - Apple Team ID を `project.yml` に反映
- `scripts/run_mac_host.sh`
  - Mac 側アプリの build / copy / relaunch
- `scripts/install_padtrack.sh`
  - iPad 側アプリの build / install
- `scripts/open_xcode.sh`
  - Xcode プロジェクトを開く

## 3. 現在の機能

### 接続

- `MultipeerConnectivity` で iPad と Mac を自動発見
- 同一ネットワーク上で接続
- iPad 側から再接続可能
- 他の Mac でも `scripts/` から起動しやすいよう整理済み

### ポインタ操作

- 1 本指ドラッグでカーソル移動
- 1 本指タップで左クリック
- 1 本指ダブルタップでダブルクリック
- 1 本指長押し後の移動でドラッグ操作
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
- 左上には設定ボタンと同じ列に横並びのアクションバーがあり、明るさ、戻る / 進む、Mission Control、Launchpad、デスクトップ表示、メディア操作、音量変更を直接押せる
- 設定画面の先頭に `画面バージョン v1.0.0 (2026-04-01e)` を表示し、反映確認ができる
- メイン画面下部の接続カードにも `画面バージョン v1.0.0 (2026-04-01e)` を表示し、古いアプリが残っていないかその場で確認できる
- 上部アクションバーは `ScrollView` ではなく固定横並びボタンにして、タップを拾いやすくしている

## 4. 起動方法

### クローン直後の基本手順

```bash
./scripts/bootstrap.sh
./scripts/run_mac_host.sh
./scripts/install_padtrack.sh DEVICE_ID
```

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

- スクロール方向は設定値と体感がずれやすく、確認しながら調整中
- 一部のジェスチャーは macOS の公開 API 制約上、ショートカット近似で実装している
- 実機確認ベースで、上部アクションバーの `戻る`、`LB`、`デスク`、`KB-`、`KB+`、`再生` は未解決の不安定項目として継続調査が必要

## 7. 直近の状態

- iPad と Mac の接続自体は可能
- Mac 側のアクセシビリティ問題は、`/Users/atsushi/Applications/MacPointerHost.app` を許可対象にする方式で安定化
- UI は日本語化済み
- 座標系バグを修正し、カーソル縦方向の不安定さを解消
- ポインタ加速を導入し、遅い動きと速い動きの操作感を改善
- スクロールモメンタム（慣性スクロール）を追加し、Magic Trackpad に近い自然なスクロール感を実現
- 2 本指スクロール方向は継続調整中
- カーソルのカクつき改善として、iPad 側と Mac 側の両方で 60fps 基準の移動集約を入れている
- 実機ベースの今後の課題メモとして、上部アクションバーでは `戻る`、`LB`、`デスク`、`KB-`、`KB+`、`再生` の動作確認と修正が残っている
- 速い移動でのもっさり感対策として、Mac 側の移動集約は外し、iPad 側だけ 60fps 集約にして反応優先へ戻している
- カーソルの感触調整用に、移動速度に加えて加速度と加速開始位置を設定画面から変えられる
- 設定画面の `ポイントとクリック` には、移動感をすぐ戻せる `標準` / `おすすめ` のプリセットを追加

## 8. 更新ログ

### 2026-04-01 (2回目)

- **座標系バグを修正**: Mac 側 `PointerController` で `NSEvent.mouseLocation`（AppKit 座標: y が下から上）を CG グローバル座標（y が上から下）として誤用していた問題を修正。初回移動でカーソルが上下反転した位置に飛ぶ現象および画面端付近の垂直方向の不安定さを解消。
- **複数ディスプレイの境界補正も修正**: `NSScreen.frame`（AppKit 座標系）から CG 座標系への変換を `cgScreenFrames()` ヘルパーにまとめ、マルチモニター環境のクランプも正確に動作するように修正。
- **ポインタ加速を追加**: 小さい移動は線形のまま精密操作を維持し、速い移動は加速する非線形カーブを `TouchpadViewModel.accelerate(_:)` として実装。Magic Trackpad の「遅い動きは精確、速い動きは大きく」という特性に近づけた。
- **スクロールモメンタム（慣性スクロール）を追加**: 2本指をリフトした後、最後の速度から減速しながらスクロールが継続する「コースト」動作を実装。`scrollWheelEventMomentumPhase` を使って macOS 側スクロールバーのフェードや inertia 対応アプリが自然に反応するようにした。

### 2026-04-01 (3回目)

- **カーソルのカクつき対策を更新**: iPad 側 [TouchpadViewModel.swift](/Users/atsushi/Desktop/ipad_mouse/Apps/PadTrack/TouchpadViewModel.swift) のポインタ移動送信を、タッチイベントごとの即送信から、画面フレームごとの集約送信へ変更。1 フレーム内の移動量をまとめて 1 回だけ送る方式にした。
- **このまま据え置く**: ポインタ移動イベントの transport は `unreliable` のまま維持する。用途上、1 イベントの欠落よりも遅延増加の方が体感悪化しやすいため、ここは低遅延優先の設計を維持する。
- **このまま据え置く**: Mac 側の加速カーブは今回いじらない。まず送信粒度の改善だけで滑らかさを見る方針で、加速カーブの再調整は必要になった時だけ行う。
- **上部アクションバーを拡張**: iPad 側上部ボタン列に `デスクトップを表示` を追加。明るさ、Mission Control、Launchpad、デスクトップ、メディア操作、音量変更を上から直接実行できる構成にそろえた。
- **追加のカクつき対策**: iPad 側の移動送信フレームレートを 60fps に固定し、Mac 側 [PointerController.swift](/Users/atsushi/Desktop/ipad_mouse/Apps/MacPointerHost/PointerController.swift) でも受信移動量を 60fps タイマーで集約してからカーソルへ反映する方式を追加。
- **このまま据え置く**: クリック前だけは未反映の移動を先に flush して、押下位置のズレを防ぐ実装を維持する。
- **反応優先へ再調整**: 速い動きでもっさり感が出たため、Mac 側の移動集約は廃止。iPad 側のみ 60fps 集約を残し、Mac 側は受信次第すぐ反映する方式へ戻した。
- **上部ボタン表示を強化**: iPad 側上部アクションバーを `safeAreaInset` 配置へ変更し、明るさやデスクトップ表示などのボタンが常に見える位置へ出るように調整。
- **設定ボタンと同列の操作バーへ変更**: iPad 側 [PadTrackApp.swift](/Users/atsushi/Desktop/ipad_mouse/Apps/PadTrack/PadTrackApp.swift) の上部ボタン群を、設定ボタンの右に横並びで続く固定パネルとして再配置。
- **加速度カーブを設定から変更可能に**: iPad 側 [TouchpadViewModel.swift](/Users/atsushi/Desktop/ipad_mouse/Apps/PadTrack/TouchpadViewModel.swift) に `カーソル加速度` と `加速開始` を追加し、ユーザーが動きのカーブを調整できるようにした。
- **最新版確認表示を追加**: 設定シートの先頭に `最新版 2026-04-01b` を表示する行を追加。反映されているビルドかどうかを iPad 上で即確認できるようにした。
- **上部アクションバーを視認重視へ再調整**: 設定ボタンに `設定` ラベルを付け、各アクションボタンにも短い文字ラベルを追加。上部バーを `VStack + HStack` の単純な固定レイアウトに変更し、左上に見えやすく配置した。
- **上部アクションバーのタップ判定を改善**: iPad 側のアクションボタン群を横スクロールコンテナから固定 `HStack` に変更し、各ボタンを `plain` スタイルで明示的にタップ可能にした。
- **Mac 側アクションのフォールバックを追加**: メディアキー系は system-defined event を `cghid` と `session` の両方へ post するようにし、Mission Control はアプリ起動フォールバックも追加した。
- **戻る / 進むボタンを追加**: iPad 側上部アクションバーに `戻る` と `進む` を追加し、Safari などのページ移動を直接押せるようにした。
- **長押しドラッグを追加**: 1 本指を短く長押しすると左ボタン押下状態に入り、そのまま移動でドラッグできるようにした。
- **版表示をさらに強化**: 設定シートだけでなく、メイン画面下部の接続カードにも `最新版 2026-04-01d` を表示するようにし、古いビルドが残っているかすぐ判別できるようにした。
- **`LP` と `戻る / 進む` の実行経路を強化**: Mac 側 [PointerController.swift](/Users/atsushi/Desktop/ipad_mouse/Apps/MacPointerHost/PointerController.swift) で、`Launchpad` は `NX_KEYTYPE_LAUNCH_PANEL` の system key を送るように変更。`戻る / 進む` は Command ショートカットを `cghid` と `session` の両方へ post するようにした。
- **版表示を `v1.x` 形式へ変更**: 設定画面とメイン画面の両方に `画面バージョン v1.0.0 (2026-04-01e)` を表示するように変更。ユーザーと「いま見えている画面がどの版か」を合わせやすくした。
- **`LP` と `戻る / 進む` のフォールバックを追加**: `戻る / 進む` のキーボードショートカットを `cghid` / `session` / `annotatedSession` の 3 経路へ post するように変更。`Launchpad` も system key に加えて `F4` と `fn+F4` を併用するようにした。
- **`LP` と `戻る / 進む` の実行経路をさらに追加**: `戻る / 進む` は AppleScript の `keystroke "[" / "]" using command down` もフォールバックで併用するように変更。`Launchpad` も `com.apple.launchpad.toggle` の通知送出と AppleScript の `key code 118` を追加し、環境差で効きやすい経路を増やした。
- **ブラウザ前面時の戻る / 進むを直接実行**: Safari / Chrome / Brave / Arc / Edge が前面のときは、キーボードショートカットより先に `history.back()` / `history.forward()` を AppleScript 経由で直接呼ぶように変更。`Command-[` の解釈差で `戻る` だけ効かないケースを減らす狙い。
- **移動プリセットを追加**: iPad 側設定の `ポイントとクリック` に `標準` / `おすすめ` を追加。再インストール後に設定が初期化されても、ワンタップで軽い動きへ戻せるようにした。あわせて初期値も `trackingSpeed 2.10 / accelerationStrength 0.26 / accelerationThreshold 1.10` に見直した。

### 2026-04-01 (1回目)

- iPad / Mac の基本接続機能を構築
- Mac 側アクセシビリティ導線を追加
- iPad / Mac の UI を日本語化
- 画面全体タッチパッド化と左上設定ボタン化を実施
- Magic Trackpad 風ジェスチャーを追加
- 複数ディスプレイ移動ロジックを改善
- 現在はスクロール方向と滑らかさを調整中
- 1 本指移動で coalesced touches を使うようにして、細かい中間移動を拾う改善を追加
- Mac 側スクロールに小数リマインダを導入し、小さいスクロール量が消えにくいように改善
