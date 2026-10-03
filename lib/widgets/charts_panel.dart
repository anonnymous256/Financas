import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../core/constants/icons.dart';
import '../core/theme/app_theme.dart';
import '../core/utils/dates.dart';
import '../core/utils/money.dart';
import '../models/models.dart';
import 'common.dart';

class ChartsPanel extends StatelessWidget {
  const ChartsPanel({
    super.key,
    required this.periods,
    required this.summaries,
    required this.categories,
    required this.balanceSpots,
    required this.currency,
  });

  final List<FinancialPeriod> periods;
  final List<MonthSummary> summaries;
  final List<FinanceCategory> categories;
  final List<int> balanceSpots;
  final String currency;

  MonthSummary? _summary(String key) {
    for (final item in summaries) {
      if (item.id == key) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final bar = _BarCompare(periods: periods, summaryOf: _summary, currency: currency);
    final pie = _CategoryPie(
      summary: _summary(periods.last.key),
      categories: categories,
      currency: currency,
    );
    final line = _BalanceLine(periods: periods, spots: balanceSpots, currency: currency);
    if (wide) {
      return Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: bar),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: pie),
            ],
          ),
          const SizedBox(height: 16),
          line,
        ],
      );
    }
    return Column(children: [bar, const SizedBox(height: 16), pie, const SizedBox(height: 16), line]);
  }
}

class _BarCompare extends StatelessWidget {
  const _BarCompare({required this.periods, required this.summaryOf, required this.currency});

  final List<FinancialPeriod> periods;
  final MonthSummary? Function(String key) summaryOf;
  final String currency;

  @override
  Widget build(BuildContext context) {
    var maxValue = 1.0;
    final groups = <BarChartGroupData>[];
    for (var i = 0; i < periods.length; i++) {
      final summary = summaryOf(periods[i].key);
      final income = (summary?.incomeCents ?? 0) / 100;
      final expense = (summary?.expenseCents ?? 0) / 100;
      if (income > maxValue) maxValue = income;
      if (expense > maxValue) maxValue = expense;
      groups.add(
        BarChartGroupData(
          x: i,
          barsSpace: 4,
          barRods: [
            BarChartRodData(toY: income, color: incomeColor, width: 10, borderRadius: BorderRadius.circular(6)),
            BarChartRodData(toY: expense, color: expenseColor, width: 10, borderRadius: BorderRadius.circular(6)),
          ],
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Receitas x despesas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Últimos 6 meses'),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                maxY: maxValue * 1.2,
                barGroups: groups,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= periods.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(periods[index].shortLabel, style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = rodIndex == 0 ? 'Receitas' : 'Despesas';
                      return BarTooltipItem(
                        '$label\n${formatMoney((rod.toY * 100).round(), currency: currency)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPie extends StatelessWidget {
  const _CategoryPie({required this.summary, required this.categories, required this.currency});

  final MonthSummary? summary;
  final List<FinanceCategory> categories;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final entries = summary?.expenseByCategory.entries.where((item) => item.value > 0).toList() ?? [];
    entries.sort((a, b) => b.value.compareTo(a.value));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Despesas por categoria', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            const SizedBox(height: 180, child: Center(child: Text('Sem despesas neste mês.')))
          else
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 42,
                  sections: entries.map((entry) {
                    final category = categories.where((item) => item.id == entry.key).firstOrNull;
                    return PieChartSectionData(
                      value: entry.value.toDouble(),
                      color: Color(category?.color ?? 0xFF64748B),
                      radius: 28,
                      showTitle: false,
                    );
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 12),
          ...entries.take(5).map((entry) {
            final category = categories.where((item) => item.id == entry.key).firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(iconFor(category?.icon ?? 'more_horiz'), size: 16, color: Color(category?.color ?? 0xFF64748B)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(category?.name ?? 'Outros')),
                  Text(formatMoney(entry.value, currency: currency), style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.periods, required this.spots, required this.currency});

  final List<FinancialPeriod> periods;
  final List<int> spots;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final values = spots.map((item) => item / 100).toList();
    final minY = values.isEmpty ? 0.0 : values.reduce((a, b) => a < b ? a : b);
    final maxY = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evolução do saldo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          const Text('Saldo em contas ao fim de cada mês'),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                minY: minY > 0 ? 0 : minY * 1.1,
                maxY: maxY == minY ? maxY + 1 : maxY * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= periods.length) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(periods[index].shortLabel, style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: [for (var i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i])],
                    isCurved: true,
                    color: Theme.of(context).colorScheme.primary,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map(
                          (spot) => LineTooltipItem(
                            formatMoney((spot.y * 100).round(), currency: currency),
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _First<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
