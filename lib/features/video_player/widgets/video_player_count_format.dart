String formatCompactVideoCount(int value) {
  if (value <= 0) {
    return '0';
  }
  if (value < 1000) {
    return value.toString();
  }

  String formatWithSuffix(double compactValue, String suffix) {
    final bool hasDecimal = compactValue < 10;
    final String text = hasDecimal
        ? compactValue.toStringAsFixed(1)
        : compactValue.toStringAsFixed(0);
    return '${text.replaceFirst(RegExp(r'\.0$'), '')}$suffix';
  }

  if (value < 1000000) {
    return formatWithSuffix(value / 1000, 'K');
  }

  return formatWithSuffix(value / 1000000, 'M');
}
