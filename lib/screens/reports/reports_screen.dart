import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_exception.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/export_service.dart';
import '../../services/finance_engine.dart';
import '../../widgets/common.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _filter = TxFilter(page: 1, pageSize: 500);
  ReportData? _report;
  var _loading = true;
  String? _error;
  var _prepared = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).value;
    if (uid == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ref.read(financeRepositoryProvider).queryTransactions(uid, _filter);
      if (mounted) {
        setState(() {
          _report = buildReport(page.items);
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = friendlyError(error);
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(revisionProvider, (previous, next) {
      if (previous != next) _load();
    });
    final profile = ref.watch(profileProvider).value;
    if (!_prepared && profile != null) {
      _prepared = true;
      final period = periodOf(DateTime.now(), profile.financialMonthStartDay);
      _filter.from = period.start;
      _filter.to = period.end;
      Future.microtask(_load);
    }
    final categories = ref.watch(categoriesProvider).value ?? const <FinanceCategory>[];
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    final cards = ref.watch(cardsProvider).value ?? const <CreditCardAccount>[];
    final currency = profile?.currency ?? 'BRL';
    final report = _report;
    return PageFrame(
      title: 'Relatórios',
      subtitle: 'Receitas, despesas e saldo do período escolhido.',
      actions: [
        OutlinedButton(onPressed: report == null ? null : () => _pdf(report, currency, categories), child: const Text('PDF')),
        FilledButton(onPressed: report == null ? null : () => _csv(report, currency, categories, accounts, cards), child: const Text('Excel/CSV')),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _date(context, 'De', _filter.from, (value) {
                _filter.from = value;
                _load();
              }),
              _date(context, 'Até', _filter.to, (value) {
                _filter.to = value;
                _load();
              }),
              _drop('Tipo', _filter.kind, const {'': 'Todos', 'income': 'Receitas', 'expense': 'Despesas', 'cardInstallment': 'Cartão'}, (value) {
                _filter.kind = value.isEmpty ? null : value;
                _load();
              }),
              _drop('Categoria', _filter.categoryId, {'': 'Todas', for (final item in categories) item.id: item.name}, (value) {
                _filter.categoryId = value.isEmpty ? null : value;
                _load();
              }),
              _drop('Conta', _filter.accountId, {'': 'Todas', for (final item in accounts) item.id: item.name}, (value) {
                _filter.accountId = value.isEmpty ? null : value;
                _load();
              }),
              _drop('Cartão', _filter.cardId, {'': 'Todos', for (final item in cards) item.id: item.name}, (value) {
                _filter.cardId = value.isEmpty ? null : value;
                _load();
              }),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading) const SkeletonList(count: 3) else if (_error != null) ErrorState(message: _error!, onRetry: _load) else if (report == null || report.transactions.isEmpty)
            const EmptyState(icon: Icons.insights_outlined, title: 'Sem dados no período', message: 'Ajuste os filtros ou lance uma movimentação.')
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 800 ? 3 : 1;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: columns == 1 ? 2.6 : 2,
                  children: [
                    StatCard(label: 'Receitas', value: formatMoney(report.incomeCents, currency: currency), caption: 'Total recebido', icon: Icons.south_west, color: const Color(0xFF059669)),
                    StatCard(label: 'Despesas', value: formatMoney(report.expenseCents, currency: currency), caption: 'Total gasto', icon: Icons.north_east, color: const Color(0xFFE11D48)),
                    StatCard(label: 'Saldo', value: formatMoney(report.balanceCents, currency: currency), caption: 'Receitas menos despesas', icon: Icons.balance, color: const Color(0xFF2563EB)),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            const Text('Por categoria', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            ..._byCategory(report, categories, currency),
          ],
        ],
      ),
    );
  }

  List<Widget> _byCategory(ReportData report, List<FinanceCategory> categories, String currency) {
    final totals = <String, int>{};
    for (final item in report.transactions.where((entry) => entry.kind != TxKind.income)) {
      final key = item.categoryId ?? '';
      totals[key] = (totals[key] ?? 0) + item.amountCents;
    }
    final entries = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((entry) {
      final name = categories.where((item) => item.id == entry.key).map((item) => item.name).firstOrNull ?? 'Sem categoria';
      return ListTile(contentPadding: EdgeInsets.zero, title: Text(name), trailing: Text(formatMoney(entry.value, currency: currency)));
    }).toList();
  }

  Future<void> _pdf(ReportData report, String currency, List<FinanceCategory> categories) async {
    try {
      await exportReportPdf(report: report, currency: currency, categories: categories);
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _csv(
    ReportData report,
    String currency,
    List<FinanceCategory> categories,
    List<BankAccount> accounts,
    List<CreditCardAccount> cards,
  ) async {
    try {
      final path = await exportReportCsv(report: report, currency: currency, categories: categories, accounts: accounts, cards: cards);
      if (mounted) showSuccess(context, path == 'relatorio-financeiro.csv' ? 'CSV gerado.' : 'CSV salvo em $path');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Widget _date(BuildContext context, String label, DateTime? value, ValueChanged<DateTime> onPick) {
    return SizedBox(
      width: 160,
      child: InkWell(
        onTap: () async {
          final picked = await pickDate(context, value ?? DateTime.now());
          if (picked != null) onPick(picked);
        },
        child: InputDecorator(decoration: InputDecoration(labelText: label), child: Text(value == null ? 'Qualquer' : formatDay(value))),
      ),
    );
  }

  Widget _drop(String label, String? value, Map<String, String> options, ValueChanged<String> onSelect) {
    return SizedBox(
      width: 190,
      child: DropdownButtonFormField<String>(
        initialValue: value ?? '',
        decoration: InputDecoration(labelText: label),
        items: options.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: (selected) => onSelect(selected ?? ''),
      ),
    );
  }
}

extension _FirstReport<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
