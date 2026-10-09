/// Date/time helpers shared by the domain and data layers.
///
/// Every time stored in the database is a UTC epoch-millisecond integer
/// (docs/ARCHITECTURE.md section 6).
library;

/// Converts a stored epoch-milliseconds value to a UTC [DateTime].
DateTime? epochMillisToDateTime(Object? value) {
  if (value == null) return null;
  return DateTime.fromMillisecondsSinceEpoch((value as num).toInt(), isUtc: true);
}

/// Converts a [DateTime] to UTC epoch milliseconds for storage.
int? dateTimeToEpochMillis(DateTime? value) =>
    value?.toUtc().millisecondsSinceEpoch;

/// The local midnight starting the week that contains [date].
///
/// Defaults to a Monday start; pass `mondayStart: false` for Sunday
/// (docs/ARCHITECTURE.md section 12).
DateTime startOfWeek(DateTime date, {bool mondayStart = true}) {
  final day = DateTime(date.year, date.month, date.day);
  final weekday = day.weekday; // 1 = Monday ... 7 = Sunday.
  final daysSinceStart = mondayStart ? weekday - 1 : weekday % 7;
  return day.subtract(Duration(days: daysSinceStart));
}
