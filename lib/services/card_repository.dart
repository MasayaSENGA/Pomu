import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/card_item.dart';
import '../utils/closing_date_utils.dart';
import 'notification_service.dart';

/// カード情報の永続化と、締めサイクル（月次リセット）・通知の同期を担当する。
class CardRepository {
  CardRepository._internal();
  static final CardRepository instance = CardRepository._internal();

  static const _storageKey = 'card_usage_tracker.cards';

  Future<List<CardItem>> loadCards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => CardItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _saveAll(List<CardItem> cards) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(cards.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, raw);
  }

  /// カードを追加または更新する。
  /// 新規追加、または締め日を変更した場合のみサイクル（未使用状態・締め日）を作り直す。
  /// それ以外の項目変更（名前・メモ等）では進捗を保持したまま、通知内容だけ最新化する。
  Future<List<CardItem>> upsertCard(CardItem card) async {
    final cards = await loadCards();
    final index = cards.indexWhere((c) => c.id == card.id);
    final isNew = index < 0;
    final closingDayChanged = !isNew && cards[index].closingDay != card.closingDay;

    if (isNew) {
      cards.add(card);
    } else {
      card.isUsedThisCycle = cards[index].isUsedThisCycle;
      card.cycleClosingDate = cards[index].cycleClosingDate;
      cards[index] = card;
    }
    await _saveAll(cards);

    if (isNew || closingDayChanged) {
      await _resetCycleForCard(cards, card.id);
    } else if (!card.isUsedThisCycle && card.cycleClosingDate != null) {
      await NotificationService.instance.scheduleAlert(
        card: card,
        alertDateTime: card.cycleClosingDate!.add(const Duration(days: 1)),
      );
    }
    return loadCards();
  }

  Future<List<CardItem>> deleteCard(String id) async {
    final cards = await loadCards();
    cards.removeWhere((c) => c.id == id);
    await _saveAll(cards);
    await NotificationService.instance.cancelAlert(id);
    return cards;
  }

  /// $付け済み/未のチェック状態を切り替える。
  /// 使用済みにしたら通知をキャンセルし、未使用に戻したら通知を再スケジュールする。
  Future<List<CardItem>> toggleUsed(String id, bool used) async {
    final cards = await loadCards();
    final card = cards.firstWhere((c) => c.id == id);
    card.isUsedThisCycle = used;
    await _saveAll(cards);

    if (used) {
      await NotificationService.instance.cancelAlert(id);
    } else if (card.cycleClosingDate != null) {
      await NotificationService.instance.scheduleAlert(
        card: card,
        alertDateTime: card.cycleClosingDate!.add(const Duration(days: 1)),
      );
    }
    return cards;
  }

  /// アプリ起動時・フォアグラウンド復帰時に全カードのサイクルを最新化する。
  /// 締め日を跨いでいたカードは isUsedThisCycle をリセットし、
  /// 次回（締め日+1）のアラートを再スケジュールする。
  Future<List<CardItem>> syncAllCycles() async {
    final cards = await loadCards();
    var changed = false;

    for (final card in cards) {
      final target = ClosingDateUtils.currentTargetClosingDate(
        DateTime.now(),
        card.closingDay,
      );
      final needsReset = card.cycleClosingDate == null ||
          !ClosingDateUtils.isSameDate(card.cycleClosingDate!, target);

      if (needsReset) {
        card.cycleClosingDate = target;
        card.isUsedThisCycle = false;
        changed = true;
        await NotificationService.instance.scheduleAlert(
          card: card,
          alertDateTime: target.add(const Duration(days: 1)),
        );
      }
    }

    if (changed) {
      await _saveAll(cards);
    }
    return cards;
  }

  Future<void> _resetCycleForCard(List<CardItem> cards, String id) async {
    final card = cards.firstWhere((c) => c.id == id);
    final target = ClosingDateUtils.currentTargetClosingDate(
      DateTime.now(),
      card.closingDay,
    );
    card.cycleClosingDate = target;
    card.isUsedThisCycle = false;
    await _saveAll(cards);
    await NotificationService.instance.scheduleAlert(
      card: card,
      alertDateTime: target.add(const Duration(days: 1)),
    );
  }
}
