class FinancialPeriod {
  const FinancialPeriod({
    required this.start,
    required this.end,
    required this.key,
    required this.label,
    required this.shortLabel,
  });

  final DateTime start;
  final DateTime end;
  final String key;
  final String label;
  final String shortLabel;
}

const monthNames = [
  'Janeiro',
  'Fevereiro',
  'Março',
  'Abril',
  'Maio',
  'Junho',
  'Julho',
  'Agosto',
  'Setembro',
  'Outubro',
  'Novembro',
  'Dezembro',
];

const monthShort = [
  'Jan',
  'Fev',
  'Mar',
  'Abr',
  'Mai',
  'Jun',
  'Jul',
  'Ago',
  'Set',
  'Out',
  'Nov',
  'Dez',
];

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

DateTime clampedDate(int year, int month, int day) {
  final normalized = DateTime(year, month, 1);
  final last = DateTime(normalized.year, normalized.month + 1, 0).day;
  final safeDay = day < 1 ? 1 : (day > last ? last : day);
  return DateTime(normalized.year, normalized.month, safeDay);
}

int clampStartDay(int day) => day < 1 ? 1 : (day > 28 ? 28 : day);

FinancialPeriod periodOf(DateTime date, int startDay) {
  final day = clampStartDay(startDay);
  final start = date.day >= day
      ? DateTime(date.year, date.month, day)
      : DateTime(date.year, date.month - 1, day);
  final next = DateTime(start.year, start.month + 1, day);
  final end = next.subtract(const Duration(seconds: 1));
  return FinancialPeriod(
    start: start,
    end: end,
    key:
        '${start.year}-${start.month.toString().padLeft(2, '0')}',
    label: '${monthNames[start.month - 1]} ${start.year}',
    shortLabel: monthShort[start.month - 1],
  );
}

List<FinancialPeriod> recentPeriods(DateTime now, int startDay, int count) {
  final current = periodOf(now, startDay);
  return List<FinancialPeriod>.generate(count, (index) {
    final offset = count - 1 - index;
    final anchor = DateTime(
      current.start.year,
      current.start.month - offset,
      current.start.day,
    );
    return periodOf(anchor, startDay);
  });
}

String formatDay(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
