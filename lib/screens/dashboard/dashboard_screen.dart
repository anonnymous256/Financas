import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/finance_engine.dart';
import '../../widgets/charts_panel.dart';
import '../../widgets/common.dart';
import '../../widgets/finance_forms.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final accounts = ref.watch(accountsProvider);
    final summaries = ref.watch(summariesProvider);
    final invoices = ref.watch(invoicesProvider);
    final categories = ref.watch(categoriesProvider);
    final currency = profile.value?.currency ?? 'BRL';

    if (profile.isLoading || accounts.isLoading || summaries.isLoading) {
      return const PageFrame(title: 'Dashboard', child: SkeletonList());
    }
    if (profile.hasError || accounts.hasError) {
      return PageFrame(
        title: 'Dashboard',
        child: ErrorState(message: 'Não conseguimos carregar o seu resumo.', onRetry: () => ref.invalidate(accountsProvider)),
      );
    }

    final startDay = profile.value?.financialMonthStartDay ?? 1;
    final periods = recentPeriods(DateTime.now(), startDay, 6);
    final current = _summary(summaries.value ?? const [], periods.last.key);
    final previous = periods.length > 1 ? _summary(summaries.value ?? const [], periods[periods.length - 2].key) : null;
    final accountList = accounts.value ?? const <BankAccount>[];
    final total = accountList.fold<int>(0, (sum, item) => sum + item.balanceCents);
    final period = periods.last;
    final pendingBills = current?.pendingExpenseCents ?? 0;
    final invoiceDue = (invoices.value ?? const <Invoice>[]).where((invoice) {
      final due = invoice.dueDate;
      return !due.isBefore(period.start) && !due.isAfter(period.end);
    }).fold<int>(0, (sum, invoice) => sum + invoice.remainingCents);
    final stillToPay = pendingBills + invoiceDue;
    final income = current?.incomeCents ?? 0;
    final expense = current?.expenseCents ?? 0;
    final monthBalance = income - expense;
    final change = percentChange(expense, previous?.expenseCents ?? 0);
    final categoryName = _name(categories.value ?? const [], current?.topCategoryId ?? '');
    final spots = _balanceSpots(accountList, summaries.value ?? const [], periods);
    final minimum = profile.value?.minimumBalanceCents ?? 0;

    return PageFrame(
      title: 'Olá, ${profile.value?.name.split(' ').first ?? ''}',
      subtitle: periods.last.label,
      actions: [
        FilledButton.icon(
          onPressed: () => showMovementForm(context, kind: TxKind.expense),
          icon: const Icon(Icons.add),
          label: const Text('Nova despesa'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (minimum > 0 && total < minimum)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: warningColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text('Seu saldo está abaixo do limite configurado. Atual: ${formatMoney(total, currency: currency)}.'),
            ),
          _SpendingMoney(
            accounts: accountList,
            selectedId: profile.value?.spendingAccountId ?? '',
            currency: currency,
          ),
          const SizedBox(height: 16),
          _Stats(
            currency: currency,
            total: total,
            income: income,
            expense: expense,
            monthBalance: monthBalance,
            stillToPay: stillToPay,
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  previous == null || previous.expenseCents == 0
                      ? 'Este é o seu primeiro mês com despesas registradas.'
                      : change == 0
                          ? 'Você gastou o mesmo que no mês passado.'
                          : 'Você gastou ${change.abs()}% ${change > 0 ? 'a mais' : 'a menos'} que no mês passado.',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(categoryName.isEmpty ? 'Ainda não há uma categoria em destaque.' : 'Sua maior categoria de gastos: $categoryName — ${formatMoney(current?.expenseByCategory[current.topCategoryId] ?? 0, currency: currency)}'),
                const SizedBox(height: 4),
                Text((current?.topExpenseCents ?? 0) == 0 ? 'Nenhuma despesa lançada neste mês.' : 'Sua maior despesa: ${current!.topExpenseDescription} — ${formatMoney(current.topExpenseCents, currency: currency)}'),
                const SizedBox(height: 4),
                Text('Você ainda possui ${formatMoney(total, currency: currency)} disponíveis nas contas.'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ChartsPanel(
            periods: periods,
            summaries: summaries.value ?? const [],
            categories: categories.value ?? const [],
            balanceSpots: spots,
            currency: currency,
          ),
          const SizedBox(height: 16),
          if ((summaries.value ?? const <MonthSummary>[]).isEmpty)
            EmptyState(
              icon: Icons.account_balance_outlined,
              title: accountList.isEmpty ? 'Comece pela primeira conta' : 'Seu painel ainda está vazio',
              message: 'Cadastre uma conta e a primeira movimentação para ver o resumo aqui.',
              action: FilledButton(onPressed: () => showAccountForm(context), child: const Text('Cadastrar conta')),
            ),
        ],
      ),
    );
  }
}

class _SpendingMoney extends ConsumerWidget {
  const _SpendingMoney({required this.accounts, required this.selectedId, required this.currency});

  final List<BankAccount> accounts;
  final String selectedId;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (accounts.isEmpty) {
      return AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Para gastar no mês', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Cadastre uma conta para separar o dinheiro do mês.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => showAccountForm(context), child: const Text('Cadastrar conta')),
          ],
        ),
      );
    }
    final selected = accounts.where((item) => item.id == selectedId).firstOrNull ?? accounts.first;
    final others = accounts.where((item) => item.id != selected.id).toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Para gastar no mês', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 8),
          Text(formatMoney(selected.balanceCents, currency: currency), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 32)),
          const SizedBox(height: 4),
          Text('Na conta ${selected.name}'),
          const SizedBox(height: 12),
          DropdownButton<String>(
            value: selected.id,
            items: accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
            onChanged: (value) async {
              if (value == null || value == selected.id) return;
              final profile = ref.read(profileProvider).value;
              if (profile == null) return;
              try {
                await ref.read(financeActionsProvider).run((bundle) {
                  FinanceEngine.updateProfile(bundle, bundle.profile.copyWith(spendingAccountId: value));
                });
              } catch (error) {
                if (context.mounted) showError(context, friendlyError(error));
              }
            },
          ),
          const SizedBox(height: 8),
          if (others.isEmpty)
            const Text('Cadastre outra conta para abastecer esta.')
          else
            FilledButton.icon(
              onPressed: () => showFundSpendingForm(context, selected),
              icon: const Icon(Icons.add_card_outlined),
              label: const Text('Abastecer'),
            ),
        ],
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({
    required this.currency,
    required this.total,
    required this.income,
    required this.expense,
    required this.monthBalance,
    required this.stillToPay,
  });

  final String currency;
  final int total;
  final int income;
  final int expense;
  final int monthBalance;
  final int stillToPay;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(label: 'Saldo total', value: formatMoney(total, currency: currency), caption: 'Disponível nas contas', icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF0F766E)),
      StatCard(label: 'Receitas do mês', value: formatMoney(income, currency: currency), caption: 'Total recebido', icon: Icons.south_west, color: incomeColor),
      StatCard(label: 'Despesas do mês', value: formatMoney(expense, currency: currency), caption: 'Contas e cartão', icon: Icons.north_east, color: expenseColor),
      StatCard(label: 'Saldo do mês', value: formatMoney(monthBalance, currency: currency), caption: 'Receitas menos despesas', icon: Icons.balance, color: const Color(0xFF2563EB)),
      StatCard(label: 'Falta pagar', value: formatMoney(stillToPay, currency: currency), caption: 'Neste mês', icon: Icons.event_available_outlined, color: warningColor),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200 ? 5 : constraints.maxWidth >= 800 ? 3 : constraints.maxWidth >= 520 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: columns == 1 ? 2.4 : 1.45,
          children: cards,
        );
      },
    );
  }
}

MonthSummary? _summary(List<MonthSummary> items, String key) {
  for (final item in items) {
    if (item.id == key) return item;
  }
  return null;
}

String _name(List<FinanceCategory> categories, String id) {
  for (final category in categories) {
    if (category.id == id) return category.name;
  }
  return '';
}

List<int> _balanceSpots(List<BankAccount> accounts, List<MonthSummary> summaries, List<FinancialPeriod> periods) {
  final ordered = [...summaries]..sort((a, b) => a.id.compareTo(b.id));
  var running = accounts.fold<int>(0, (sum, account) => sum + account.initialBalanceCents);
  final first = periods.first.key;
  for (final summary in ordered.where((item) => item.id.compareTo(first) < 0)) {
    running += summary.balanceDeltaCents;
  }
  return [
    for (final period in periods)
      running += ordered.where((item) => item.id == period.key).fold(0, (sum, item) => sum + item.balanceDeltaCents),
  ];
}
