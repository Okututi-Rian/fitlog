/// Turns a snake_case token like `full_body` into `Full Body` for display.
String humanize(String value) {
  return value
      .split('_')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

/// Formats a workout duration like `1h 5m`, `12m 30s` or `45s`.
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) return '${hours}h ${minutes}m';
  if (minutes > 0) return '${minutes}m ${seconds}s';
  return '${seconds}s';
}

/// Formats a rest countdown like `1:23`.
String formatCountdown(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Formats a weight in kilograms without a trailing `.0` (e.g. `60`, `62.5`).
String formatWeight(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// Parses an integer, tolerating surrounding whitespace; null if invalid.
int? parseIntOrNull(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return int.tryParse(trimmed);
}

/// Parses a decimal, tolerating a comma decimal separator; null if invalid.
double? parseDoubleOrNull(String raw) {
  final trimmed = raw.trim().replaceAll(',', '.');
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed);
}
