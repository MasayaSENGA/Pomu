import 'package:flutter_test/flutter_test.dart';

import 'package:card_usage_tracker/models/card_item.dart';
import 'package:card_usage_tracker/services/alert_schedule.dart';

CardItem _card({
  required int closingDay,
  required DateTime cycleClosingDate,
  bool isUsedThisCycle = false,
}) {
  return CardItem(
    id: 'card-1',
    name: 'テストカード',
    last4: '1234',
    closingDay: closingDay,
    usageMethod: '',
    isUsedThisCycle: isUsedThisCycle,
    cycleClosingDate: cycleClosingDate,
    notificationBlock: 1,
  );
}

void main() {
  group('AlertSchedule.build', () {
    test('先のサイクル分もまとめて予約する', () {
      // アプリを起動しない限り予約を作り直せないので、
      // 1件だけだと翌サイクル以降の通知が届かなくなる（回帰防止）。
      final slots = AlertSchedule.build(
        _card(closingDay: 15, cycleClosingDate: DateTime(2026, 8, 15)),
        DateTime(2026, 8, 10),
      );

      expect(slots.length, AlertSchedule.cycleCount);
      expect(slots.first.closingDate, DateTime(2026, 8, 15));
      expect(slots.last.closingDate, DateTime(2027, 7, 15));
    });

    test('通知は締め日翌日の9時', () {
      final slots = AlertSchedule.build(
        _card(closingDay: 15, cycleClosingDate: DateTime(2026, 8, 15)),
        DateTime(2026, 8, 10),
      );

      expect(slots.first.alertAt, DateTime(2026, 8, 16, 9, 0));
    });

    test('今サイクルが \$付け済みなら、そのサイクルだけ除外して先の分は残す', () {
      final slots = AlertSchedule.build(
        _card(
          closingDay: 15,
          cycleClosingDate: DateTime(2026, 8, 15),
          isUsedThisCycle: true,
        ),
        DateTime(2026, 8, 10),
      );

      expect(slots.length, AlertSchedule.cycleCount - 1);
      expect(slots.first.closingDate, DateTime(2026, 9, 15));
    });

    test('既に過ぎた日時は予約しない', () {
      // 長期間アプリを開かず、サイクルが取り残されている状況。
      final slots = AlertSchedule.build(
        _card(closingDay: 15, cycleClosingDate: DateTime(2026, 1, 15)),
        DateTime(2026, 8, 1),
      );

      expect(slots.map((s) => s.closingDate), [
        DateTime(2026, 8, 15),
        DateTime(2026, 9, 15),
        DateTime(2026, 10, 15),
        DateTime(2026, 11, 15),
        DateTime(2026, 12, 15),
      ]);
    });

    test('締め日が月末に丸められるカードでも各サイクルを正しく辿る', () {
      final slots = AlertSchedule.build(
        _card(closingDay: 31, cycleClosingDate: DateTime(2026, 1, 31)),
        DateTime(2026, 1, 1),
      );

      expect(slots[0].closingDate, DateTime(2026, 1, 31));
      expect(slots[1].closingDate, DateTime(2026, 2, 28));
      expect(slots[2].closingDate, DateTime(2026, 3, 31));
      expect(slots[3].closingDate, DateTime(2026, 4, 30));
    });

    test('枝番は締め日の月で決まり、1カード内で重複しない', () {
      // 同じ月の予約が必ず同じIDになることで、予約し直しても
      // 二重に登録されず、確実に上書き更新される。
      final slots = AlertSchedule.build(
        _card(closingDay: 15, cycleClosingDate: DateTime(2026, 8, 15)),
        DateTime(2026, 8, 10),
      );

      expect(slots.map((s) => s.slot).toSet().length, slots.length);
      expect(slots.every((s) => s.slot >= 0), isTrue);
      expect(slots.every((s) => s.slot < AlertSchedule.slotsPerCard), isTrue);
      expect(slots.first.slot, 7); // 8月 → 枝番 7
    });

    test('サイクル数は枝番が月で一意になる範囲に収まっている', () {
      expect(AlertSchedule.cycleCount, lessThanOrEqualTo(12));
      expect(AlertSchedule.slotsPerCard,
          greaterThanOrEqualTo(AlertSchedule.cycleCount));
    });

    test('サイクル未設定のカードは何も予約しない', () {
      final card = CardItem(
        id: 'x',
        name: 'x',
        last4: '0000',
        closingDay: 10,
        usageMethod: '',
      );
      expect(AlertSchedule.build(card, DateTime(2026, 8, 1)), isEmpty);
    });
  });
}
