import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/defaults.dart';
import '../../core/constants/icons.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/finance_engine.dart';
import '../../widgets/common.dart';
import '../../widgets/finance_forms.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    return PageFrame(
      title: 'Minhas contas',
      subtitle: 'O saldo acompanha receitas, despesas e transferências.',
      actions: [FilledButton.icon(onPressed: () => showAccountForm(context), icon: const Icon(Icons.add), label: const Text('Nova conta'))],
      child: accounts.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(accountsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.account_balance_outlined,
              title: 'Nenhuma conta cadastrada',
              message: 'Adicione a conta em que o seu dinheiro está hoje.',
              action: FilledButton(onPressed: () => showAccountForm(context), child: const Text('+ Adicionar conta')),
            );
          }
          return Column(
            children: items.map((account) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Row(
                    children: [
                      CircleAvatar(backgroundColor: Color(account.color).withValues(alpha: 0.15), child: Icon(iconFor(account.icon), color: Color(account.color))),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            Text('${account.bank.isEmpty ? accountTypeLabels[account.type] : account.bank} • ${accountTypeLabels[account.type] ?? account.type}'),
                          ],
                        ),
                      ),
                      Text(formatMoney(account.balanceCents, currency: currency), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            showAccountForm(context, existing: account);
                          } else {
                            final ok = await confirmAction(context, title: 'Excluir conta', message: 'Só é possível excluir contas sem movimentações.', confirmLabel: 'Excluir', destructive: true);
                            if (!ok || !context.mounted) return;
                            await _run(context, ref, (bundle) => FinanceEngine.deleteAccount(bundle, account.id), 'Conta excluída.');
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class CardsScreen extends ConsumerWidget {
  const CardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(cardsProvider);
    final invoices = ref.watch(invoicesProvider).value ?? const <Invoice>[];
    final purchases = ref.watch(purchasesProvider).value ?? const <CardPurchase>[];
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    return PageFrame(
      title: 'Cartões',
      subtitle: 'Acompanhe limite, compras e parcelas. O número completo nunca aparece.',
      actions: [FilledButton.icon(onPressed: () => showCardForm(context), icon: const Icon(Icons.add), label: const Text('Novo cartão'))],
      child: cards.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(cardsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(icon: Icons.credit_card, title: 'Nenhum cartão', message: 'Cadastre um cartão para lançar compras parceladas.', action: FilledButton(onPressed: () => showCardForm(context), child: const Text('+ Adicionar cartão')));
          }
          return Column(
            children: items.map((card) {
              final used = invoices.where((item) => item.cardId == card.id).fold<int>(0, (sum, item) => sum + item.remainingCents);
              final available = card.limitCents - used;
              final cardPurchases = purchases.where((item) => item.cardId == card.id && item.source != FinanceEngine.ongoingSource).toList();
              final upcoming = FinanceEngine.upcomingStatementMonths(card.closingDay, count: 6);
              final currentMonth = upcoming.first;
              final currentInvoice = invoices
                  .where((item) => item.cardId == card.id && item.year == currentMonth.year && item.month == currentMonth.month)
                  .firstOrNull;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(backgroundColor: Color(card.color), child: const Icon(Icons.credit_card, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('${card.name} • final ${card.lastFour}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') showCardForm(context, existing: card);
                              if (value == 'buy') showMovementForm(context, kind: TxKind.expense);
                              if (value == 'delete') {
                                final ok = await confirmAction(context, title: 'Excluir cartão', message: 'Só é possível excluir cartões sem compras.', confirmLabel: 'Excluir', destructive: true);
                                if (!ok || !context.mounted) return;
                                await _run(context, ref, (bundle) => FinanceEngine.deleteCard(bundle, card.id), 'Cartão excluído.');
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'buy', child: Text('Nova compra')),
                              PopupMenuItem(value: 'edit', child: Text('Editar')),
                              PopupMenuItem(value: 'delete', child: Text('Excluir')),
                            ],
                          ),
                        ],
                      ),
                      Text('${card.brand} • fecha dia ${card.closingDay} • vence dia ${card.dueDay}'),
                      const SizedBox(height: 12),
                      Text('Limite ${formatMoney(card.limitCents, currency: currency)}'),
                      Text('Utilizado ${formatMoney(used, currency: currency)}'),
                      Text('Disponível ${formatMoney(available, currency: currency)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(
                        'Fatura atual • ${monthNames[currentMonth.month - 1]} ${formatMoney(currentInvoice?.remainingCents ?? 0, currency: currency)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      if (currentInvoice != null && currentInvoice.remainingCents > 0) ...[
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: () async {
                            final message = await showPayInvoiceForm(context, currentInvoice);
                            if (message != null && context.mounted) showSuccess(context, message);
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Pagar fatura atual'),
                        ),
                      ],
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: card.limitCents == 0 ? 0 : (used / card.limitCents).clamp(0, 1), minHeight: 8, borderRadius: BorderRadius.circular(8)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => showOngoingAmountsForm(context, card),
                        icon: const Icon(Icons.event_note_outlined),
                        label: const Text('Valores que já vêm'),
                      ),
                      ...upcoming.map((month) {
                        final invoice = invoices
                            .where((item) => item.cardId == card.id && item.year == month.year && item.month == month.month)
                            .firstOrNull;
                        if (invoice == null || invoice.totalCents <= 0) return const SizedBox.shrink();
                        final paidOff = invoice.remainingCents <= 0;
                        final label = paidOff
                            ? '${monthNames[month.month - 1]} ${month.year}: ${formatMoney(invoice.totalCents, currency: currency)} • paga'
                            : invoice.paidCents > 0
                                ? '${monthNames[month.month - 1]} ${month.year}: ${formatMoney(invoice.remainingCents, currency: currency)} pendente'
                                : '${monthNames[month.month - 1]} ${month.year}: ${formatMoney(invoice.totalCents, currency: currency)}';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(label),
                        );
                      }),
                      if (cardPurchases.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        ...cardPurchases.map((purchase) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(purchase.description),
                              subtitle: Text('${formatDay(purchase.date)} • ${purchase.installments}x de ${formatMoney(purchase.totalCents ~/ purchase.installments, currency: currency)}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () async {
                                  final ok = await confirmAction(context, title: 'Excluir compra', message: 'As parcelas em aberto serão removidas.', confirmLabel: 'Excluir', destructive: true);
                                  if (!ok || !context.mounted) return;
                                  await _run(context, ref, (bundle) => FinanceEngine.deletePurchase(bundle, purchase.id), 'Compra excluída.');
                                },
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String? _cardId;
  String? _categoryId;
  String _scope = 'open';

  @override
  Widget build(BuildContext context) {
    final invoices = ref.watch(invoicesProvider);
    final cards = ref.watch(cardsProvider).value ?? const <CreditCardAccount>[];
    final categories = ref.watch(categoriesProvider).value ?? const <FinanceCategory>[];
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    return PageFrame(
      title: 'Faturas',
      subtitle: 'Veja a fatura atual, as próximas e as anteriores.',
      actions: [
        if (cards.isNotEmpty)
          FilledButton.icon(
            onPressed: () {
              final card = cards.where((item) => item.id == _cardId).firstOrNull ?? cards.first;
              showOngoingAmountsForm(context, card);
            },
            icon: const Icon(Icons.event_note_outlined),
            label: const Text('Valores que já vêm'),
          ),
      ],
      child: invoices.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(invoicesProvider)),
        data: (items) {
          final filtered = items.where((invoice) {
            if (_cardId != null && invoice.cardId != _cardId) return false;
            if (_scope == 'open' && invoice.status == 'paid') return false;
            if (_scope == 'paid' && invoice.status != 'paid') return false;
            return true;
          }).toList();
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Nenhuma fatura',
              message: 'Informe os valores que já vêm em cada mês ou lance uma compra no cartão.',
            );
          }
          return Column(
            children: [
              Wrap(
                spacing: 12,
                children: [
                  DropdownButton<String>(
                    value: _cardId ?? '',
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos os cartões')),
                      ...cards.map((card) => DropdownMenuItem(value: card.id, child: Text(card.name))),
                    ],
                    onChanged: (value) => setState(() => _cardId = value == null || value.isEmpty ? null : value),
                  ),
                  DropdownButton<String>(
                    value: _scope,
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Em aberto')),
                      DropdownMenuItem(value: 'paid', child: Text('Pagas')),
                      DropdownMenuItem(value: 'all', child: Text('Todas')),
                    ],
                    onChanged: (value) => setState(() => _scope = value ?? 'open'),
                  ),
                  DropdownButton<String>(
                    value: _categoryId ?? '',
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todas as categorias')),
                      ...categories.where((item) => item.kind == 'expense').map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))),
                    ],
                    onChanged: (value) => setState(() => _categoryId = value == null || value.isEmpty ? null : value),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...filtered.map((invoice) => _InvoiceTile(invoice: invoice, currency: currency, categoryId: _categoryId)),
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceTile extends ConsumerWidget {
  const _InvoiceTile({required this.invoice, required this.currency, required this.categoryId});

  final Invoice invoice;
  final String currency;
  final String? categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = (ref.watch(cardsProvider).value ?? const <CreditCardAccount>[]).where((item) => item.id == invoice.cardId).firstOrNull;
    return FutureBuilder<TxPage>(
      future: ref.read(financeRepositoryProvider).queryTransactions(
            ref.read(authStateProvider).value ?? '',
            TxFilter(cardId: invoice.cardId, kind: TxKind.cardInstallment, pageSize: 100),
          ),
      builder: (context, snapshot) {
        final items = (snapshot.data?.items ?? const <FinanceTransaction>[]).where((item) => item.invoiceId == invoice.id && (categoryId == null || item.categoryId == categoryId)).toList();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${card?.name ?? 'Cartão'} • ${monthNames[invoice.month - 1]} ${invoice.year}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Fecha ${formatDay(invoice.closingDate)} • vence ${formatDay(invoice.dueDate)}'),
                const SizedBox(height: 8),
                Text('Total ${formatMoney(invoice.totalCents, currency: currency)} • pago ${formatMoney(invoice.paidCents, currency: currency)} • pendente ${formatMoney(invoice.remainingCents, currency: currency)}'),
                const SizedBox(height: 8),
                StatusChip(status: invoice.status),
                const SizedBox(height: 8),
                ...items.map((item) => ListTile(contentPadding: EdgeInsets.zero, title: Text(item.description), trailing: Text(formatMoney(item.amountCents, currency: currency)))),
                const SizedBox(height: 8),
                if (invoice.remainingCents > 0)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final message = await showPayInvoiceForm(context, invoice);
                        if (message != null && context.mounted) showSuccess(context, message);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(invoice.paidCents > 0 ? 'Pagar restante' : 'Pagar fatura'),
                    ),
                  ),
                if (invoice.paidCents > 0)
                  TextButton(
                    onPressed: () => _run(context, ref, (bundle) => FinanceEngine.undoInvoicePayment(bundle, invoice.id), 'Pagamento desfeito.'),
                    child: const Text('Desfazer pagamento'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(transfersProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    return PageFrame(
      title: 'Transferências',
      subtitle: 'Mover dinheiro entre as suas contas não conta como receita nem despesa.',
      actions: [FilledButton.icon(onPressed: () => showTransferForm(context), icon: const Icon(Icons.compare_arrows), label: const Text('Transferir'))],
      child: transfers.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(transfersProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.compare_arrows, title: 'Nenhuma transferência', message: 'Transfira entre suas contas quando precisar.');
          }
          final sorted = [...items]..sort((a, b) => b.date.compareTo(a.date));
          return Column(
            children: sorted.map((transfer) {
              final from = accounts.where((item) => item.id == transfer.fromAccountId).firstOrNull?.name ?? 'Conta';
              final to = accounts.where((item) => item.id == transfer.toAccountId).firstOrNull?.name ?? 'Conta';
              return Card(
                child: ListTile(
                  title: Text('$from → $to'),
                  subtitle: Text('${formatDay(transfer.date)} ${transfer.notes.isEmpty ? '' : '• ${transfer.notes}'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatMoney(transfer.amountCents, currency: currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirmAction(context, title: 'Excluir transferência', message: 'Os saldos das duas contas serão ajustados.', confirmLabel: 'Excluir', destructive: true);
                          if (!ok || !context.mounted) return;
                          await _run(context, ref, (bundle) => FinanceEngine.deleteTransfer(bundle, transfer.id), 'Transferência excluída.');
                        },
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class RecurringScreen extends ConsumerWidget {
  const RecurringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(recurringProvider);
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    return PageFrame(
      title: 'Contas recorrentes',
      subtitle: 'Aluguel, internet, assinaturas e outras contas que se repetem.',
      actions: [FilledButton.icon(onPressed: () => showRecurringForm(context), icon: const Icon(Icons.add), label: const Text('Nova recorrência'))],
      child: items.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(recurringProvider)),
        data: (list) {
          final visible = list.where((item) => !item.variable).toList();
          if (visible.isEmpty) {
            return EmptyState(icon: Icons.event_repeat, title: 'Nenhuma conta recorrente', message: 'Cadastre Netflix, aluguel, internet ou academia.', action: FilledButton(onPressed: () => showRecurringForm(context), child: const Text('+ Adicionar')));
          }
          return Column(
            children: visible.map((item) {
              return Card(
                child: ListTile(
                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${item.kind == 'income' ? 'Receita' : 'Despesa'} • ${frequencyLabels[item.frequency] ?? item.frequency} • dia ${item.dueDay} • ${item.active ? 'Ativa' : 'Pausada'}'
                    '${item.startsOn == null ? '' : ' • a partir de ${formatDay(item.startsOn!)}'}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(formatMoney(item.amountCents, currency: currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                      PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'edit') showRecurringForm(context, existing: item);
                          if (value == 'delete') {
                            final ok = await confirmAction(context, title: 'Excluir recorrência', message: 'Os lançamentos já gerados permanecem.', confirmLabel: 'Excluir', destructive: true);
                            if (!ok || !context.mounted) return;
                            await _run(context, ref, (bundle) => FinanceEngine.deleteRecurring(bundle, item.id), 'Recorrência excluída.');
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Excluir')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

class GoalsScreen extends ConsumerWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goals = ref.watch(goalsProvider);
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    return PageFrame(
      title: 'Metas',
      subtitle: 'Acompanhe objetivos como a reserva, uma viagem ou um carro.',
      actions: [FilledButton.icon(onPressed: () => showGoalForm(context), icon: const Icon(Icons.add), label: const Text('Nova meta'))],
      child: goals.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(goalsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(icon: Icons.flag_outlined, title: 'Nenhuma meta', message: 'Crie um objetivo e acompanhe o progresso.', action: FilledButton(onPressed: () => showGoalForm(context), child: const Text('+ Criar meta')));
          }
          return Column(
            children: items.map((goal) {
              final percent = (goal.progress * 100).round();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(iconFor(goal.icon), color: Color(goal.color)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
                          Text('$percent%', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      if (goal.description.isNotEmpty) Text(goal.description),
                      const SizedBox(height: 8),
                      Text('${formatMoney(goal.currentCents, currency: currency)} de ${formatMoney(goal.targetCents, currency: currency)}'),
                      if (goal.deadline != null) Text('Prazo ${formatDay(goal.deadline!)}'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: goal.progress.toDouble(), minHeight: 10, borderRadius: BorderRadius.circular(8), color: Color(goal.color)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(onPressed: () => _contribute(context, ref, goal.id, 10000), child: const Text('+ R\$ 100')),
                          OutlinedButton(onPressed: () => showGoalForm(context, existing: goal), child: const Text('Editar')),
                          TextButton(
                            onPressed: () async {
                              final ok = await confirmAction(context, title: 'Excluir meta', message: 'A meta será removida.', confirmLabel: 'Excluir', destructive: true);
                              if (!ok || !context.mounted) return;
                              await _run(context, ref, (bundle) => FinanceEngine.deleteGoal(bundle, goal.id), 'Meta excluída.');
                            },
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Future<void> _contribute(BuildContext context, WidgetRef ref, String id, int cents) {
    return _run(context, ref, (bundle) => FinanceEngine.contributeGoal(bundle, id, cents), 'Valor adicionado à meta.');
  }
}

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return PageFrame(
      title: 'Categorias',
      subtitle: 'Cada usuário tem as próprias categorias.',
      actions: [FilledButton.icon(onPressed: () => showCategoryForm(context), icon: const Icon(Icons.add), label: const Text('Nova categoria'))],
      child: categories.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(categoriesProvider)),
        data: (items) {
          final incomes = items.where((item) => item.kind == 'income').toList();
          final expenses = items.where((item) => item.kind == 'expense').toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Receitas', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...incomes.map((item) => _categoryTile(context, ref, item)),
              const SizedBox(height: 16),
              const Text('Despesas', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...expenses.map((item) => _categoryTile(context, ref, item)),
            ],
          );
        },
      ),
    );
  }

  Widget _categoryTile(BuildContext context, WidgetRef ref, FinanceCategory item) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Color(item.color).withValues(alpha: 0.15), child: Icon(iconFor(item.icon), color: Color(item.color))),
        title: Text(item.name),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'edit') showCategoryForm(context, existing: item);
            if (value == 'delete') {
              final ok = await confirmAction(context, title: 'Excluir categoria', message: 'Categorias em uso não podem ser excluídas.', confirmLabel: 'Excluir', destructive: true);
              if (!ok || !context.mounted) return;
              await _run(context, ref, (bundle) => FinanceEngine.deleteCategory(bundle, item.id), 'Categoria excluída.');
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);
    return PageFrame(
      title: 'Notificações',
      subtitle: 'Faturas, contas, metas e saldo.',
      actions: [
        OutlinedButton(
          onPressed: () => _run(context, ref, FinanceEngine.markAllNotificationsRead, 'Notificações marcadas como lidas.'),
          child: const Text('Marcar todas como lidas'),
        ),
      ],
      child: notifications.when(
        loading: () => const SkeletonList(),
        error: (error, _) => ErrorState(message: friendlyError(error), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.notifications_none, title: 'Tudo em dia', message: 'Você não tem notificações no momento.');
          }
          final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return Column(
            children: sorted.map((item) {
              return Card(
                child: ListTile(
                  leading: Icon(item.read ? Icons.notifications_none : Icons.notifications_active_outlined),
                  title: Text(item.title, style: TextStyle(fontWeight: item.read ? FontWeight.w500 : FontWeight.w800)),
                  subtitle: Text('${item.body}\n${formatDay(item.createdAt)}'),
                  onTap: item.read ? null : () => _run(context, ref, (bundle) => FinanceEngine.markNotificationRead(bundle, item.id), 'Notificação lida.'),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

Future<void> _run(
  BuildContext context,
  WidgetRef ref,
  void Function(UserBundle bundle) change,
  String success,
) async {
  try {
    await ref.read(financeActionsProvider).run(change);
    if (context.mounted) showSuccess(context, success);
  } catch (error) {
    if (context.mounted) showError(context, friendlyError(error));
  }
}

extension _FirstRecord<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
