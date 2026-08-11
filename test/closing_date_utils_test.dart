import 'package:flutter_test/flutter_test.dart';

import 'package:card_usage_tracker/utils/closing_date_utils.dart';

void main() {
  group('closingDateFor', () {
    test('その月に存在する締め日はそのまま返す', () {
      expect(
        ClosingDateUtils.closingDateFor(2026, 8, 15),
        DateTime(2026, 8, 15),
      );
    });

    test('存在しない締め日は月末にクランプされる', () {
      expect(
        ClosingDateUtils.closingDateFor(2026, 2, 31),
        DateTime(2026, 2, 28),
      );
      expect(
        ClosingDateUtils.closingDateFor(2024, 2, 31), // うるう年
        DateTime(2024, 2, 29),
      );
      expect(
        ClosingDateUtils.closingDateFor(2026, 4, 31),
        DateTime(2026, 4, 30),
      );
    });
  });

  group('currentTargetClosingDate', () {
    test('締め日前なら当月の締め日', () {
      expect(
        ClosingDateUtils.currentTargetClosingDate(DateTime(2026, 8, 10), 15),
        DateTime(2026, 8, 15),
      );
    });

    test('締め日当日なら当月の締め日', () {
      expect(
        ClosingDateUtils.currentTargetClosingDate(DateTime(2026, 8, 15), 15),
        DateTime(2026, 8, 15),
      );
    });

    test('締め日を過ぎていれば翌月の締め日', () {
      expect(
        ClosingDateUtils.currentTargetClosingDate(DateTime(2026, 8, 16), 15),
        DateTime(2026, 9, 15),
      );
    });

    test('年をまたぐ場合', () {
      expect(
        ClosingDateUtils.currentTargetClosingDate(DateTime(2026, 12, 20), 15),
        DateTime(2027, 1, 15),
      );
    });

    test('翌月に存在しない締め日は月末に丸められる', () {
      expect(
        ClosingDateUtils.currentTargetClosingDate(DateTime(2026, 1, 31), 31),
        DateTime(2026, 1, 31),
      );
      expect(
        ClosingDateUtils.currentTargetClosingDate(DateTime(2026, 2, 1), 31),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('currentTargetClosingDate（サイクル切り替えを通知時刻に揃えた場合）', () {
    // 実アプリでは rolloverHour = AlertSchedule.hour(9時) を渡す。
    DateTime target(DateTime now, int closingDay) =>
        ClosingDateUtils.currentTargetClosingDate(now, closingDay,
            rolloverHour: 9);

    test('締め日翌日でも通知時刻前なら、まだ前サイクルを追いかける', () {
      // ここで翌サイクルへ進んでしまうと、その日の通知が
      // 同じIDで上書き予約されて発火しなくなる（回帰防止）。
      expect(target(DateTime(2026, 8, 16, 7), 15), DateTime(2026, 8, 15));
    });

    test('通知時刻ちょうどで次サイクルへ切り替わる', () {
      expect(target(DateTime(2026, 8, 16, 9), 15), DateTime(2026, 9, 15));
    });

    test('締め日当日は当月のサイクル', () {
      expect(target(DateTime(2026, 8, 15, 23, 59), 15), DateTime(2026, 8, 15));
    });

    test('月末クランプされたサイクルでも、翌月1日の通知時刻前は前サイクル', () {
      // 9月は30日までなので締め日は 9/30、通知は 10/1 9:00。
      expect(target(DateTime(2026, 10, 1, 7), 31), DateTime(2026, 9, 30));
      expect(target(DateTime(2026, 10, 1, 9), 31), DateTime(2026, 10, 31));
    });

    test('年をまたぐ場合', () {
      expect(target(DateTime(2027, 1, 1, 7), 31), DateTime(2026, 12, 31));
      expect(target(DateTime(2027, 1, 1, 9), 31), DateTime(2027, 1, 31));
    });
  });

  group('nextClosingDateAfter', () {
    test('翌月の締め日を返す', () {
      expect(
        ClosingDateUtils.nextClosingDateAfter(DateTime(2026, 8, 15), 15),
        DateTime(2026, 9, 15),
      );
    });

    test('年をまたぐ', () {
      expect(
        ClosingDateUtils.nextClosingDateAfter(DateTime(2026, 12, 15), 15),
        DateTime(2027, 1, 15),
      );
    });

    test('月末にクランプされていても、元の締め日を基準に計算する', () {
      // 2/28 の次は 3/28 ではなく 3/31。
      expect(
        ClosingDateUtils.nextClosingDateAfter(DateTime(2026, 2, 28), 31),
        DateTime(2026, 3, 31),
      );
      expect(
        ClosingDateUtils.nextClosingDateAfter(DateTime(2026, 1, 31), 31),
        DateTime(2026, 2, 28),
      );
    });
  });

  group('daysUntil', () {
    test('締め日までの残り日数', () {
      expect(
        ClosingDateUtils.daysUntil(DateTime(2026, 8, 10), DateTime(2026, 8, 15)),
        5,
      );
    });

    test('当日は 0', () {
      expect(
        ClosingDateUtils.daysUntil(
          DateTime(2026, 8, 15, 23, 30),
          DateTime(2026, 8, 15),
        ),
        0,
      );
    });

    test('過ぎていれば負の値', () {
      expect(
        ClosingDateUtils.daysUntil(DateTime(2026, 8, 18), DateTime(2026, 8, 15)),
        -3,
      );
    });
  });

  test('isSameDate は時刻を無視して日付だけ比較する', () {
    expect(
      ClosingDateUtils.isSameDate(
        DateTime(2026, 8, 15, 23, 59),
        DateTime(2026, 8, 15, 0, 0),
      ),
      isTrue,
    );
    expect(
      ClosingDateUtils.isSameDate(DateTime(2026, 8, 15), DateTime(2026, 9, 15)),
      isFalse,
    );
  });
}
