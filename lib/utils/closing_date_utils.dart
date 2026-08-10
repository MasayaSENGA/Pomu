/// 締め日に関する日付計算をまとめたユーティリティ。
class ClosingDateUtils {
  /// [year]年[month]月における締め日を返す。
  /// closingDay がその月に存在しない日付（31日等）の場合は月末日にクランプする。
  static DateTime closingDateFor(int year, int month, int closingDay) {
    final lastDayOfMonth = DateTime(year, month + 1, 0).day;
    final day = closingDay > lastDayOfMonth ? lastDayOfMonth : closingDay;
    return DateTime(year, month, day);
  }

  /// [today]時点で「今アプリが追いかけるべきサイクルの締め日」を返す。
  /// 今日が今月の締め日以前ならまだ今月の締め日を、
  /// 締め日を過ぎていれば来月の締め日を対象とする。
  static DateTime currentTargetClosingDate(DateTime today, int closingDay) {
    final thisMonthClosing =
        closingDateFor(today.year, today.month, closingDay);
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    if (!todayDateOnly.isAfter(thisMonthClosing)) {
      return thisMonthClosing;
    }

    final nextMonthFirstDay = DateTime(today.year, today.month + 1, 1);
    return closingDateFor(
      nextMonthFirstDay.year,
      nextMonthFirstDay.month,
      closingDay,
    );
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
