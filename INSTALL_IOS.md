# iPhone に Pomu をインストールする（無料の Apple ID を使う方法）

Apple Developer Program に入らなくても、自分の Apple ID で署名すれば実機にインストールできます。
ただし **署名の有効期限は 7 日間** で、切れるとアプリが起動しなくなります。使い続けるには
7日ごとに再インストール（下記の手順6をもう一度）してください。

> このプロジェクトの iOS 最低対応バージョンは **15.0** です（Xcode 27 の要件に合わせて設定済み）。

## 必要なもの

- Mac（Xcode がインストール済み）
- iPhone と USB ケーブル
- Apple ID（普段使っているもので構いません）

Xcode がまだなら App Store から入れて、一度起動してライセンスに同意しておいてください。
その後、ターミナルで次を実行しておきます。

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
flutter doctor -v
```

`flutter doctor` の Xcode の行にチェックが付いていれば準備完了です。

---

## 1. iPhone を Mac につなぐ

USB で接続し、iPhone 側に「このコンピュータを信頼しますか？」が出たら **信頼** を選びます。

## 2. iPhone でデベロッパモードを有効にする（iOS 16 以降）

一度 Xcode からビルドを試みると、この項目が iPhone の設定に現れます。

```
設定 → プライバシーとセキュリティ → デベロッパモード → オン
```

オンにすると再起動を求められます。再起動後、パスコードを入力すると有効になります。

## 3. Xcode でプロジェクトを開く

```bash
cd /Users/user/Develop/Pomu
open ios/Runner.xcworkspace
```

`.xcodeproj` ではなく **`.xcworkspace`** を開いてください。

## 4. 署名の設定

左のファイル一覧で一番上の **Runner** をクリック →
中央の **TARGETS → Runner** を選択 → **Signing & Capabilities** タブを開きます。

1. **Automatically manage signing** にチェックを入れる
2. **Team** のプルダウンから **Add an Account...** を選び、Apple ID でサインイン
3. サインイン後、Team に「あなたの名前 (Personal Team)」が出るので選択
4. **Bundle Identifier** が世界で一意になっているか確認する
   （`com.example.*` のままだと他の人と衝突して失敗します）

`Signing Certificate: Apple Development` と表示されればOKです。

## 5. 実機を選ぶ

Xcode 上部のデバイス選択（再生ボタンの右）で、接続した iPhone を選びます。

## 6. インストールする

ターミナルに戻って実行します。

```bash
cd /Users/user/Develop/Pomu
flutter devices          # iPhone が一覧に出るか確認
flutter run --release
```

> **`--release` を付けるのが重要です。**
> デバッグビルドは Mac とつながっていないと起動できません。リリースビルドなら
> ケーブルを抜いた後も単体で動きます。

## 7. iPhone 側で開発元を信頼する

初回はインストール直後に「信頼されていないデベロッパ」と出て起動できません。

```
設定 → 一般 → VPNとデバイス管理 → デベロッパApp → あなたの Apple ID → 信頼
```

これでホーム画面の Pomu アイコンから起動できます。

## 8. 通知を許可する

初回起動時に通知の許可を聞かれるので **許可** を選んでください。
断ってしまった場合は `設定 → Pomu → 通知` から後で有効にできます。

---

## 7日経って起動しなくなったら

証明書の期限切れです。iPhone をつないで、もう一度これを実行するだけで復活します。

```bash
cd /Users/user/Develop/Pomu
flutter run --release
```

登録済みのカードのデータは端末内に残っているので消えません。

## 期限を気にせず使いたい場合

Apple Developer Program（年 $99）に登録すると署名が 1 年有効になり、
TestFlight を使えばケーブル無しで配布・更新できるようになります。

---

## うまくいかないとき

| 症状 | 対処 |
| --- | --- |
| `No profiles for 'xxx' were found` | Bundle Identifier が他と衝突しています。手順4-4 で一意な値に変更 |
| `Unable to install` / `device is locked` | iPhone のロックを解除した状態で再実行 |
| `Developer Mode disabled` | 手順2 のデベロッパモードを有効化 |
| デバイスが `flutter devices` に出ない | ケーブルを挿し直し、iPhone 側で「信頼」を選び直す |
| ビルドは通るがアプリが即終了する | `--release` を付け忘れていないか確認 |
| 署名まわりが直らない | `flutter clean` の後、Xcode で `Product → Clean Build Folder` を実行して再試行 |
