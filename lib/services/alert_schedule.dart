import '../models/card_item.dart';
import '../utils/closing_date_utils.dart';

/// 通知1件分の予約内容。
class AlertSlot {
  const AlertSlot({
    required this.closingDate,
    required this.alertAt,
  });

  /// このアラートが対象とするサイクルの締め日。
  final DateTime closingDate;

  /// 実際に通知を出す日時（締め日翌日の [AlertSchedule.hour] 時）。
  final DateTime alertAt;

  /// カード内での通知IDの枝番。締め日の「月」で決まるため、
  /// 同じ月の予約は何度作り直しても必ず同じIDになる（＝上書き更新される）。
  int get slot => closingDate.month - 1;

  @override
  String toString() => 'AlertSlot(slot: $slot, alertAt: $alertAt)';
}

/// 「いつ・いくつの通知を予約するか」を決める純粋なロジック。
///
/// プラグインに触れないので単体テストできる。実際の予約は
/// [NotificationService] がこの結果をそのまま実行する。
class AlertSchedule {
  AlertSchedule._();

  /// 通知を送る時刻。サイクルの切り替わり時刻も必ずこれに揃える
  /// （[ClosingDateUtils.currentTargetClosingDate] の rolloverHour）。
  static const int hour = 9;
  static const int minute = 0;

  /// 何サイクル先まで前倒しで予約するか。
  ///
  /// アプリを開いたときにしか予約を作り直せないため、まとめて先の分まで
  /// 押さえておく。12 を超えると [AlertSlot.slot] が月で一意にならないので
  /// 12 が上限。
  static const int cycleCount = 12;

  /// 1カードに確保する通知IDの幅。[cycleCount] より大きくしておく。
  static const int slotsPerCard = 16;

  /// 締め日 [closingDate] に対応するアラート日時（＝翌日の [hour] 時）。
  static DateTime alertAtFor(DateTime closingDate) => DateTime(
        closingDate.year,
        closingDate.month,
        closingDate.day + 1,
        hour,
        minute,
      );

  /// [card] について、[now] 以降に発火すべきアラートを列挙する。
  ///
  /// - 現在サイクルが $付け済みなら、そのサイクル分だけ除外して先の分は残す。
  /// - 既に過ぎている日時は含めない。
  static List<AlertSlot> build(CardItem card, DateTime now) {
    final currentClosing = card.cycleClosingDate;
    if (currentClosing == null) return const [];

    final slots = <AlertSlot>[];
    var closing = currentClosing;
    for (var cycle = 0; cycle < cycleCount; cycle++) {
      if (cycle > 0) {
        closing = ClosingDateUtils.nextClosingDateAfter(closing, card.closingDay);
      }
      // 今サイクルだけは、$付け済みならアラート不要。
      if (cycle == 0 && card.isUsedThisCycle) continue;

      final alertAt = alertAtFor(closing);
      if (!alertAt.isAfter(now)) continue;

      slots.add(AlertSlot(closingDate: closing, alertAt: alertAt));
    }
    return slots;
  }
}

/// カードのアラート予約を操作する窓口。
/// テストでは差し替えられるようにインターフェースにしてある。
abstract class AlertScheduler {
  /// [card] の予約を現在の状態に合わせて作り直す（不要な枝番は取り消す）。
  Future<void> syncAlerts(CardItem card);

  /// [card] の予約をすべて取り消す。
  Future<void> cancelAlerts(CardItem card);

  /// 旧方式（カードIDのハッシュ1件のみ）で予約された通知を取り消す。
  /// 通知IDを枝番方式へ移行した際、取り残しが二重通知になるのを防ぐ。
  Future<void> cancelLegacyAlert(String cardId);
}
