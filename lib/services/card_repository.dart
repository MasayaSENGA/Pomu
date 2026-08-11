import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_item.dart';
import '../utils/closing_date_utils.dart';
import 'alert_schedule.dart';
import 'notification_service.dart';

/// カード情報の永続化と、締めサイクル（月次リセット）・通知の同期を担当する。
///
/// すべての公開メソッドは内部のキューで直列化される。読み込み→書き換え→保存を
/// 挟む処理なので、並行して走ると後勝ちで更新が消える（例: 2枚を素早く連続で
/// タップすると片方のチェックが戻る）ため。
class CardRepository {
  /// アプリからは [instance] を使う。テストでは通知側を差し替えて生成する。
  CardRepository(this._scheduler);

  static final CardRepository instance =
      CardRepository(NotificationService.instance);

  final AlertScheduler _scheduler;

  static const _storageKey = 'card_usage_tracker.cards';

  /// 読み込めなかったデータの退避先。消さずに残しておけば後から調査できる。
  static const _corruptedKey = 'card_usage_tracker.cards.corrupted';

  /// 最後に通知の予約をまとめて作り直した日付（yyyy-MM-dd）。
  static const _lastAlertSyncKey = 'card_usage_tracker.lastAlertSync';

  /// 通知IDのブロック番号の上限（26bit）。
  /// ブロック番号 × [AlertSchedule.slotsPerCard] が 32bit に収まるようにしている。
  static const int _blockSpace = 0x03FFFFFF;

  Future<void> _queue = Future<void>.value();

  bool _dataWasDropped = false;

  /// 破損データを読み捨てた直後だけ true になる。UI で一度だけ知らせるため、
  /// 確認したら [acknowledgeDroppedData] でクリアする。
  bool get dataWasDropped => _dataWasDropped;

  void acknowledgeDroppedData() => _dataWasDropped = false;

  /// 通知の予約を試みる。成功したかどうかを返す。
  ///
  /// 通知はあくまで補助機能なので、ここで例外を投げさせない。
  /// 投げると保存やカード一覧の読み込みまで巻き添えで失敗してしまう。
  Future<bool> _trySchedule(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// [action] を直前の操作の完了後に実行する。
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<void>();
    final previous = _queue;
    _queue = completer.future;
    return previous.then((_) => action()).whenComplete(completer.complete);
  }

  Future<List<CardItem>> loadCards() => _synchronized(_load);

  /// 保存済みデータを読む。**例外を投げない**。
  ///
  /// ここで投げると呼び出し元の画面がローディングのまま固まり、
  /// しかも再起動しても同じデータで同じ例外になって復帰できなくなる。
  Future<List<CardItem>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    List<dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      // 全体が壊れている場合のみ、退避したうえで空にする。
      await prefs.setString(_corruptedKey, raw);
      await prefs.remove(_storageKey);
      _dataWasDropped = true;
      return [];
    }

    final cards = <CardItem>[];
    for (final entry in decoded) {
      try {
        cards.add(CardItem.fromJson(entry as Map<String, dynamic>));
      } catch (_) {
        // 1件だけ壊れていても、残りのカードは読めるので続行する。
        _dataWasDropped = true;
      }
    }
    return cards;
  }

  Future<void> _saveAll(List<CardItem> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(cards.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  /// カードを追加または更新する。
  /// 新規追加、または締め日を変更した場合のみサイクル（未使用状態・締め日）を作り直す。
  /// それ以外の項目変更（名前・メモ等）では進捗を保持したまま、通知内容だけ最新化する。
  Future<List<CardItem>> upsertCard(CardItem card) {
    return _synchronized(() async {
      final cards = await _load();
      final index = cards.indexWhere((c) => c.id == card.id);
      final isNew = index < 0;
      final closingDayChanged =
          !isNew && cards[index].closingDay != card.closingDay;

      if (isNew) {
        card.notificationBlock ??= _assignBlock(cards, card);
        cards.add(card);
      } else {
        // 進捗と通知IDは編集画面が持っていないので、保存済みの値を引き継ぐ。
        card.isUsedThisCycle = cards[index].isUsedThisCycle;
        card.cycleClosingDate = cards[index].cycleClosingDate;
        card.notificationBlock =
            cards[index].notificationBlock ?? _assignBlock(cards, card);
        cards[index] = card;
      }

      if (isNew || closingDayChanged) {
        card.cycleClosingDate = _targetClosingDateFor(card);
        card.isUsedThisCycle = false;
      }

      await _saveAll(cards);
      await _trySchedule(() => _scheduler.syncAlerts(card));
      return cards;
    });
  }

  Future<List<CardItem>> deleteCard(String id) {
    return _synchronized(() async {
      final cards = await _load();
      final index = cards.indexWhere((c) => c.id == id);
      if (index < 0) return cards;

      final removed = cards.removeAt(index);
      await _saveAll(cards);
      await _trySchedule(() => _scheduler.cancelAlerts(removed));
      return cards;
    });
  }

  /// $付け済み/未のチェック状態を切り替える。
  /// 使用済みにしたら今サイクルの通知をキャンセルし、未使用に戻したら復活させる。
  /// いずれの場合も次サイクル以降の予約はそのまま残る。
  Future<List<CardItem>> toggleUsed(String id, bool used) {
    return _synchronized(() async {
      final cards = await _load();
      final index = cards.indexWhere((c) => c.id == id);
      // 削除直後にトグルが飛んでくることがあるので、無ければ黙って何もしない。
      if (index < 0) return cards;

      final card = cards[index];
      card.isUsedThisCycle = used;
      await _saveAll(cards);
      await _trySchedule(() => _scheduler.syncAlerts(card));
      return cards;
    });
  }

  /// アプリ起動時・フォアグラウンド復帰時に全カードのサイクルを最新化する。
  ///
  /// 締め日を跨いでいたカードは isUsedThisCycle をリセットする。あわせて、
  /// 1日1回は全カードの予約を作り直して先のサイクル分を補充する
  /// （途中で権限が許可された場合や、予約が消えた場合の復旧も兼ねる）。
  Future<List<CardItem>> syncAllCycles() {
    return _synchronized(() async {
      final cards = await _load();
      final prefs = await SharedPreferences.getInstance();
      final today = _dateKey(DateTime.now());
      final alertsAreStale = prefs.getString(_lastAlertSyncKey) != today;

      var changed = false;
      for (final card in cards) {
        // 旧データには通知IDのブロックが無い。採番したうえで、
        // 旧方式で残っている予約を取り消して二重通知を防ぐ。
        if (card.notificationBlock == null) {
          card.notificationBlock = _assignBlock(cards, card);
          await _trySchedule(() => _scheduler.cancelLegacyAlert(card.id));
          changed = true;
        }

        final target = _targetClosingDateFor(card);
        if (card.cycleClosingDate == null ||
            !ClosingDateUtils.isSameDate(card.cycleClosingDate!, target)) {
          card.cycleClosingDate = target;
          card.isUsedThisCycle = false;
          changed = true;
        }
      }

      if (changed) {
        await _saveAll(cards);
      }
      if (changed || alertsAreStale) {
        var allScheduled = true;
        for (final card in cards) {
          final ok = await _trySchedule(() => _scheduler.syncAlerts(card));
          allScheduled = allScheduled && ok;
        }
        // 失敗した場合は記録を残さず、次回の復帰時にもう一度やり直す。
        if (allScheduled) {
          await prefs.setString(_lastAlertSyncKey, today);
        }
      }
      return cards;
    });
  }

  /// 追跡すべきサイクルの締め日。サイクルの切り替わりは通知時刻に揃える。
  DateTime _targetClosingDateFor(CardItem card) =>
      ClosingDateUtils.currentTargetClosingDate(
        DateTime.now(),
        card.closingDay,
        rolloverHour: AlertSchedule.hour,
        rolloverMinute: AlertSchedule.minute,
      );

  /// 他のカードと重複しない通知IDのブロック番号を採番する。
  int _assignBlock(List<CardItem> cards, CardItem card) {
    final used = <int>{
      for (final c in cards)
        if (c.id != card.id && c.notificationBlock != null) c.notificationBlock!,
    };
    var block = card.id.hashCode & _blockSpace;
    while (used.contains(block)) {
      block = (block + 1) & _blockSpace;
    }
    return block;
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';
}
