import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/card_item.dart';
import 'alert_schedule.dart';

/// 端末内ローカル通知のスケジュール管理を行うサービス。
/// サーバーは使わず、flutter_local_notifications のみで完結する。
///
/// 通知は「次の1回」ではなく [AlertSchedule.cycleCount] サイクル先まで
/// まとめて予約する。アプリを起動しない限り予約を作り直せないため、
/// 1回分しか入れていないと、アプリを開かない月以降の通知が途切れてしまう。
class NotificationService implements AlertScheduler {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'card_alerts';
  static const String _channelName = 'カード利用アラート';
  static const String _channelDescription = '締め日翌日に未利用のカードをお知らせします';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // 端末のタイムゾーンを自動取得したい場合は flutter_timezone パッケージ等の
    // 利用を検討してください。ここでは日本時間を既定値にしています。
    tz.setLocalLocation(tz.getLocation('Asia/Tokyo'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(initSettings);

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// 通知権限をリクエストする（Android 13+ / iOS）。
  ///
  /// 戻り値は許可されたかどうか。判定できないプラットフォーム
  /// （権限の概念が無い環境など）では null を返す。
  Future<bool?> requestPermissions() async {
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    if (android == null && ios == null) return null;
    return (android ?? true) && (ios ?? true);
  }

  /// カード＋枝番から通知IDを決める。
  ///
  /// ブロック番号は端末に保存された値なので、`String.hashCode` のように
  /// 実行ごとの安定性が保証されない値に依存しない
  /// （＝あとから確実にキャンセルできる）。
  int _notificationId(int block, int slot) =>
      block * AlertSchedule.slotsPerCard + slot;

  @override
  Future<void> syncAlerts(CardItem card) async {
    final block = card.notificationBlock;
    if (block == null) return;

    final now = tz.TZDateTime.now(tz.local);
    final wanted = <int, AlertSlot>{
      for (final slot in AlertSchedule.build(card, DateTime.now()))
        slot.slot: slot,
    };

    // 予約すべき枝番は上書き、それ以外は取り消す。
    // 枝番は締め日の「月」で決まるので、同じ月の予約は毎回同じIDになり、
    // 予約し直しても既存の予約が消えたり二重になったりしない。
    for (var slot = 0; slot < AlertSchedule.slotsPerCard; slot++) {
      final target = wanted[slot];
      final id = _notificationId(block, slot);
      if (target == null) {
        await _plugin.cancel(id);
        continue;
      }

      final scheduled = tz.TZDateTime(
        tz.local,
        target.alertAt.year,
        target.alertAt.month,
        target.alertAt.day,
        target.alertAt.hour,
        target.alertAt.minute,
      );
      if (!scheduled.isAfter(now)) {
        await _plugin.cancel(id);
        continue;
      }

      await _plugin.zonedSchedule(
        id,
        '\$付け忘れ注意：${card.name}',
        '締め日（${target.closingDate.month}/${target.closingDate.day}）が過ぎました。'
            'このサイクルはまだ利用登録（\$付け）されていません。',
        scheduled,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> cancelAlerts(CardItem card) async {
    final block = card.notificationBlock;
    if (block == null) return;
    for (var slot = 0; slot < AlertSchedule.slotsPerCard; slot++) {
      await _plugin.cancel(_notificationId(block, slot));
    }
  }

  @override
  Future<void> cancelLegacyAlert(String cardId) async {
    await _plugin.cancel(cardId.hashCode & 0x7fffffff);
  }
}
