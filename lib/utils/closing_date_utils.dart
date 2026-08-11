/// 締め日に関する日付計算をまとめたユーティリティ。
class ClosingDateUtils {
  /// [year]年[month]月における締め日を返す。
  /// closingDay がその月に存在しない日付（31日等）の場合は月末日にクランプする。
  static DateTime closingDateFor(int year, int month, int closingDay) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = closingDay > lastDayOfMonth ? lastDayOfMonth : closingDay;
    return DateTime(year, month, day);
  }

  /// [closing] の次のサイクルの締め日を返す。
  /// 締め日が月末にクランプされていても、元の [closingDay] を基準に計算する
  /// （例: 2/28 の次は、closingDay=31 なら 3/31）。
  static DateTime nextClosingDateAfter(DateTime closing, int closingDay) {
    final nextMonth = DateTime(closing.year, closing.month + 1, 1);
    return closingDateFor(nextMonth.year, nextMonth.month, closingDay);
  }

  /// [now] 時点で「今アプリが追いかけるべきサイクルの締め日」を返す。
  ///
  /// サイクルは締め日当日ではなく、**締め日翌日の [rolloverHour]:[rolloverMinute]**
  /// に次サイクルへ切り替わる。これはアラートの発火時刻と揃えるためで、
  /// 締め日翌日の朝（アラート発火前）にアプリを開いても、
  /// まだ前サイクルの未対応が残っている状態を維持できる。
  static DateTime currentTargetClosingDate(
    DateTime now,
    int closingDay, {
    int rolloverHour = 0,
    int rolloverMinute = 0,
  }) {
    DateTime rolloverOf(DateTime closing) => DateTime(
          closing.year,
          closing.month,
          closing.day + 1,
          rolloverHour,
          rolloverMinute,
        );

    // 前月・当月・翌月の3つが候補になる。
    // 前月が候補に入るのは、締め日翌日のロールオーバー時刻前にいる場合。
    final previousMonth = DateTime(now.year, now.month - 1, 1);
    final previousClosing = closingDateFor(
      previousMonth.year,
      previousMonth.month,
      closingDay,
    );
    if (now.isBefore(rolloverOf(previousClosing))) {
      return previousClosing;
    }

    final thisClosing = closingDateFor(now.year, now.month, closingDay);
    if (now.isBefore(rolloverOf(thisClosing))) {
      return thisClosing;
    }

    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return closingDateFor(nextMonth.year, nextMonth.month, closingDay);
  }

  /// [today] から [target]（締め日）までの残り日数。
  /// 当日は 0、過ぎている場合は負の値を返す。
  static int daysUntil(DateTime today, DateTime target) {
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(target.year, target.month, target.day);
    return b.difference(a).inDays;
  }

  static bool isSameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
