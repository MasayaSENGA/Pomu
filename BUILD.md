# ビルド手順

プロジェクトはリポジトリ直下（このファイルと同じ階層）に統合済みです。
以下をターミナルで実行してください。

```bash
cd /Users/user/Develop/card_usage_tracker

flutter pub get        # 依存解決（pubspec.lock が生成されます）
flutter analyze        # 静的解析
flutter test           # ユニットテスト（締め日計算）
```

## 各プラットフォームのビルド

```bash
# Android（APK）
flutter build apk --debug

# iOS（シミュレータ用・署名不要）
flutter build ios --debug --simulator

# macOS
flutter build macos --debug

# 実機/シミュレータで起動
flutter run
```

## 注意

- **Web は非対応**です。`flutter_local_notifications` が `dart:io` に依存しているため
  `flutter build web` は失敗します。通知が不要なら該当パッケージを外してください。
- Android は `flutter_local_notifications` の要件により
  **core library desugaring** を有効化済み（`android/app/build.gradle.kts`）。
- リリースビルドは `android/app/build.gradle.kts` の署名設定（現在 debug 鍵）と、
  `applicationId` / `PRODUCT_BUNDLE_IDENTIFIER` の `com.example.*` を
  自分のものに変更してから行ってください。

## 依存関係でエラーが出た場合

`pubspec.yaml` の `flutter_local_notifications` はバージョン範囲指定（`>=18.0.1 <20.0.0`）
にしてあります。解決に失敗する場合は次を試してください。

```bash
flutter pub upgrade --major-versions
```
