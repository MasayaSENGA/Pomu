import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/card_item.dart';

/// 端末内ローカル通知のスケジュール管理を行うサービス。
/// サーバーは使わず、flutter_local_notifications のみで完結する。
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// 通知を送る時刻（毎回この時刻を狙って送信）。
  /// 変更したい場合はここを書き換えてください。
  static const int alertHour = 9;
  static const int alertMinute = 0;

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
  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// カードIDから決定的な通知IDを生成する（同じカードは常に同じID）。
  int _notificationIdFor(String cardId) => cardId.hashCode & 0x7fffffff;

  /// 指定した日時に、指定カードの未利用アラートをスケジュールする。
  /// 既に同じカード用の通知が存在する場合は上書きされる。
  Future<void> scheduleAlert({
    required CardItem card,
    required DateTime alertDateTime,
  }) async {
    final id = _notificationIdFor(card.id);
    final scheduled = tz.TZDateTime(
      tz.local,
      alertDateTime.year,
      alertDateTime.month,
      alertDateTime.day,
      alertHour,
      alertMinute,
    );

    // 過去日時になる場合は何もしない（次回のサイクル同期時に正しい日時で再設定される）
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) {
      return;
    }

    await _plugin.zonedSchedule(
      id,
      '\$付け忘れ注意：${card.name}',
      '締め日が過ぎました。今月まだ利用登録（\$付け）されていません。',
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

  /// 指定カードの予定済みアラートをキャンセルする（$付け済みにした時など）。
  Future<void> cancelAlert(String cardId) async {
    await _plugin.cancel(_notificationIdFor(cardId));
  }
}
