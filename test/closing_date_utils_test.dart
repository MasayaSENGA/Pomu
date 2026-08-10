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
