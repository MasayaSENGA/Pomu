# Pomu

保有しているクレジットカードを一覧管理し、毎月の締め日翌日になっても未利用（$付けしていない）カードがあればローカル通知でアラートするアプリです。サーバー・アカウント不要、データは端末内にのみ保存されます。

## できること

- カードの登録・編集・削除（カード名／下4桁／締め日／券面カラー／$付け方法メモ）
- カード券面を模した一覧。タップで当月の $付け状況をトグル、左スワイプで削除
- 締め日までの残り日数バッジ（3日以内は警告色）と、今サイクルの進捗サマリー
- 締め日翌日 9:00 に、未チェックのカードのみ端末内通知でアラート
- 月をまたぐと自動的に「未使用」状態にリセットし、次の締め日+1に再度アラートを予約
- ライト／ダークモード対応

## ビルドと実行

ビルド手順は [BUILD.md](BUILD.md) を参照してください。

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## 実装上の前提・注意点

- **通知時刻**：締め日翌日の 9:00 に固定。変更は `lib/services/notification_service.dart` の `alertHour` / `alertMinute`。
- **タイムゾーン**：`Asia/Tokyo` 固定。海外でも使う場合は `flutter_timezone` 等の導入を検討してください。
- **通知の精度**：バッテリー消費を抑えるため `inexactAllowWhileIdle`（多少前後する）を使用。分単位で厳密に届ける場合は Android の `SCHEDULE_EXACT_ALARM` 権限と許可導線が別途必要です。
- **データのバックアップ**：端末内保存のみのため機種変更時は引き継がれません。
- **通知タップ時の遷移**：通知タップでアプリを開くのみで、特定カードへの自動遷移は未実装です。
- **Web は非対応**：`flutter_local_notifications` が `dart:io` に依存しているためです。

## ファイル構成

| パス | 役割 |
| --- | --- |
| `lib/main.dart` | アプリ起点、通知初期化、テーマ適用 |
| `lib/theme/app_theme.dart` | 配色・角丸・券面グラデーション等のデザイントークン |
| `lib/screens/home_screen.dart` | カード一覧、進捗サマリー、空状態 |
| `lib/screens/card_edit_screen.dart` | 追加・編集フォーム（券面ライブプレビュー付き） |
| `lib/widgets/card_list_tile.dart` | カード券面風タイル |
| `lib/services/card_repository.dart` | 保存・締めサイクル管理・通知連携 |
| `lib/services/notification_service.dart` | ローカル通知のスケジュール管理 |
| `lib/utils/closing_date_utils.dart` | 締め日・残り日数の計算ロジック |
| `lib/models/card_item.dart` | カードのデータモデル |
