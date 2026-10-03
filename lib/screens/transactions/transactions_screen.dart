import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/icons.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/finance_engine.dart';
import '../../widgets/common.dart';
import '../../widgets/finance_forms.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key, this.fixedKind});

  final String? fixedKind;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  late final TxFilter _filter = TxFilter(kind: widget.fixedKind, pageSize: 8);
  final _search = TextEditingController();
  Timer? _debounce;
  TxPage? _page;
  var _loading = true;
  String? _error;
  var _prepared = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _mark(FinanceTransaction item, String status) async {
    try {
      await ref.read(financeActionsProvider).run((bundle) => FinanceEngine.setPaymentStatus(bundle, item.id, status));
      if (!mounted) return;
      if (status == 'paid' && item.recurringId != null) {
        showSuccess(context, 'Paga. Esta conta volta no próximo mês.');
      } else if (status == 'paid') {
        showSuccess(context, 'Despesa marcada como paga.');
      } else {
        showSuccess(context, 'Despesa voltou para pendente.');
      }
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
  }

  Future<void> _payMonth() async {
    final ok = await confirmAction(
      context,
      title: 'Quitar o mês',
      message: 'As despesas pendentes deste período serão marcadas como pagas. As recorrentes continuam e voltam no próximo mês.',
      confirmLabel: 'Quitar',
    );
    if (!ok || !mounted) return;
    try {
      var count = 0;
      await ref.read(financeActionsProvider).run((bundle) {
        count = FinanceEngine.payPendingExpenses(bundle, from: _filter.from, to: _filter.to);
      });
      if (mounted) showSuccess(context, count == 1 ? '1 despesa paga.' : '$count despesas pagas.');
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
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
          _page = page;
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
    final title = switch (widget.fixedKind) {
      TxKind.income => 'Receitas',
      TxKind.expense => 'Despesas',
      _ => 'Transações',
    };
    final kind = widget.fixedKind ?? TxKind.expense;
    final narrow = MediaQuery.sizeOf(context).width < 720;
    final categoryList = categories.where((item) => widget.fixedKind == null || item.kind == widget.fixedKind).toList();
    final activeFilters = _activeFilterCount();
    return PageFrame(
      title: title,
      subtitle: 'Busque, filtre e organize suas movimentações.',
      scroll: false,
      actions: [
        if (narrow)
          Badge(
            isLabelVisible: activeFilters > 0,
            label: Text('$activeFilters'),
            child: OutlinedButton.icon(
              onPressed: () => _openFilters(categoryList, accounts, cards),
              icon: const Icon(Icons.filter_list),
              label: const Text('Filtrar'),
            ),
          ),
        FilledButton.icon(
          onPressed: () => showMovementForm(context, kind: kind),
          icon: const Icon(Icons.add),
          label: Text(widget.fixedKind == TxKind.income ? 'Nova receita' : 'Nova despesa'),
        ),
        if (widget.fixedKind == TxKind.expense)
          OutlinedButton.icon(
            onPressed: _payMonth,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Quitar mês'),
          ),
      ],
      child: Column(
        children: [
          if (!narrow)
            _Filters(
              filter: _filter,
              categories: categoryList,
              accounts: accounts,
              cards: cards,
              showKind: widget.fixedKind == null,
              search: _search,
              onSearch: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _filter.search = value;
                  _filter.page = 1;
                  _load();
                });
              },
              onChanged: () {
                _filter.page = 1;
                _load();
              },
            ),
          if (!narrow) const SizedBox(height: 12),
          Expanded(child: _body(currency, categories, accounts, cards)),
        ],
      ),
    );
  }

  int _activeFilterCount() {
    var count = 0;
    if (_search.text.trim().isNotEmpty) count++;
    if (_filter.status != null && _filter.status!.isNotEmpty) count++;
    if (_filter.categoryId != null && _filter.categoryId!.isNotEmpty) count++;
    if (_filter.accountId != null && _filter.accountId!.isNotEmpty) count++;
    if (_filter.cardId != null && _filter.cardId!.isNotEmpty) count++;
    if (widget.fixedKind == null && _filter.kind != null) count++;
    return count;
  }

  Future<void> _openFilters(
    List<FinanceCategory> categories,
    List<BankAccount> accounts,
    List<CreditCardAccount> cards,
  ) async {
    final previousSearch = _search.text;
    final previousFrom = _filter.from;
    final previousTo = _filter.to;
    final previousStatus = _filter.status;
    final previousCategory = _filter.categoryId;
    final previousAccount = _filter.accountId;
    final previousCard = _filter.cardId;
    final previousKind = _filter.kind;
    final result = await showAppForm<bool>(
      context,
      child: _FilterSheet(
        filter: _filter,
        categories: categories,
        accounts: accounts,
        cards: cards,
        showKind: widget.fixedKind == null,
        search: _search,
        onApply: () {
          _filter.search = _search.text.trim();
          _filter.page = 1;
        },
        onClear: () {
          _search.clear();
          _filter.search = '';
          _filter.status = null;
          _filter.categoryId = null;
          _filter.accountId = null;
          _filter.cardId = null;
          if (widget.fixedKind == null) _filter.kind = null;
          _filter.page = 1;
        },
      ),
    );
    if (!mounted) return;
    if (result == null) {
      _search.text = previousSearch;
      _filter.search = previousSearch.trim();
      _filter.from = previousFrom;
      _filter.to = previousTo;
      _filter.status = previousStatus;
      _filter.categoryId = previousCategory;
      _filter.accountId = previousAccount;
      _filter.cardId = previousCard;
      _filter.kind = previousKind;
      return;
    }
    _load();
  }

  Widget _body(String currency, List<FinanceCategory> categories, List<BankAccount> accounts, List<CreditCardAccount> cards) {
    if (_loading) return const SkeletonList();
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    final items = _page?.items ?? const <FinanceTransaction>[];
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Você ainda não possui nenhuma transação.',
        message: 'Adicione uma receita ou despesa para começar.',
        action: FilledButton(
          onPressed: () => showMovementForm(context, kind: widget.fixedKind ?? TxKind.expense),
          child: const Text('+ Adicionar transação'),
        ),
      );
    }
    return Column(
      children: [
        if (_page?.truncated == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text('Mostrando os 500 lançamentos mais recentes do período.'),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final category = categories.where((entry) => entry.id == item.categoryId).firstOrNull;
              final account = accounts.where((entry) => entry.id == item.accountId).firstOrNull;
              final card = cards.where((entry) => entry.id == item.cardId).firstOrNull;
              final positive = item.kind == TxKind.income;
              final narrow = MediaQuery.sizeOf(context).width < 720;
              final menu = item.kind == TxKind.income || item.kind == TxKind.expense
                  ? PopupMenuButton<String>(
                      onSelected: (value) async {
                        if (value == 'edit') {
                          showMovementForm(context, kind: item.kind, existing: item);
                        } else if (value == 'paid' || value == 'pending') {
                          await _mark(item, value);
                        } else {
                          final ok = await confirmAction(context, title: 'Excluir movimentação', message: 'Essa ação não pode ser desfeita.', confirmLabel: 'Excluir', destructive: true);
                          if (!ok || !context.mounted) return;
                          try {
                            await ref.read(financeActionsProvider).run((bundle) => FinanceEngine.deleteTransaction(bundle, item.id));
                            if (context.mounted) showSuccess(context, 'Movimentação excluída.');
                          } catch (error) {
                            if (context.mounted) showError(context, friendlyError(error));
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Editar')),
                        if (item.status == 'paid') const PopupMenuItem(value: 'pending', child: Text('Voltar para pendente')),
                        const PopupMenuItem(value: 'delete', child: Text('Excluir')),
                      ],
                    )
                  : null;
              final amount = Text(
                '${positive ? '+' : '-'}${formatMoney(item.amountCents, currency: currency)}',
                style: TextStyle(fontWeight: FontWeight.w800, color: positive ? incomeColor : expenseColor),
              );
              final pay = item.kind == TxKind.expense && item.status != 'paid'
                  ? TextButton(onPressed: () => _mark(item, 'paid'), child: const Text('Pagar'))
                  : null;
              final avatar = CircleAvatar(
                backgroundColor: Color(category?.color ?? 0xFF64748B).withValues(alpha: 0.15),
                child: Icon(iconFor(category?.icon ?? 'more_horiz'), color: Color(category?.color ?? 0xFF64748B)),
              );
              final muted = Theme.of(context).colorScheme.onSurfaceVariant;
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${formatDay(item.date)} • ${category?.name ?? kindLabel(item.kind)} • ${account?.name ?? card?.name ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              );
              if (narrow) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(width: 12),
                            Expanded(child: details),
                            ?menu,
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 52),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              StatusChip(status: item.status),
                              amount,
                              ?pay,
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                child: ListTile(
                  leading: avatar,
                  title: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${formatDay(item.date)} • ${category?.name ?? kindLabel(item.kind)} • ${account?.name ?? card?.name ?? ''}'),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      ?pay,
                      StatusChip(status: item.status),
                      amount,
                      ?menu,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        PaginationBar(
          page: _page?.page ?? 1,
          pages: _page?.pages ?? 1,
          onPage: (page) {
            _filter.page = page;
            _load();
          },
        ),
      ],
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.filter,
    required this.categories,
    required this.accounts,
    required this.cards,
    required this.showKind,
    required this.search,
    required this.onApply,
    required this.onClear,
  });

  final TxFilter filter;
  final List<FinanceCategory> categories;
  final List<BankAccount> accounts;
  final List<CreditCardAccount> cards;
  final bool showKind;
  final TextEditingController search;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Filtrar',
      submitLabel: 'Aplicar',
      onSubmit: () {
        onApply();
        Navigator.pop(context, true);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Filters(
            filter: filter,
            categories: categories,
            accounts: accounts,
            cards: cards,
            showKind: showKind,
            search: search,
            stacked: true,
            onSearch: (_) {},
            onChanged: () {},
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: () {
              onClear();
              Navigator.pop(context, false);
            }, child: const Text('Limpar filtros')),
          ),
        ],
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.filter,
    required this.categories,
    required this.accounts,
    required this.cards,
    required this.showKind,
    required this.search,
    required this.onSearch,
    required this.onChanged,
    this.stacked = false,
  });

  final TxFilter filter;
  final List<FinanceCategory> categories;
  final List<BankAccount> accounts;
  final List<CreditCardAccount> cards;
  final bool showKind;
  final TextEditingController search;
  final ValueChanged<String> onSearch;
  final VoidCallback onChanged;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      TextField(
        controller: search,
        decoration: const InputDecoration(labelText: 'Buscar descrição', prefixIcon: Icon(Icons.search)),
        onChanged: onSearch,
      ),
      _date(context, 'De', filter.from, (value) {
        filter.from = value;
        onChanged();
      }),
      _date(context, 'Até', filter.to, (value) {
        filter.to = value;
        onChanged();
      }),
      if (showKind)
        _drop('Tipo', filter.kind, {
          '': 'Todos',
          TxKind.income: 'Receita',
          TxKind.expense: 'Despesa',
          TxKind.cardInstallment: 'Cartão',
          TxKind.invoicePayment: 'Pagamento de fatura',
        }, (value) {
          filter.kind = value.isEmpty ? null : value;
          onChanged();
        }),
      _drop('Status', filter.status, const {'': 'Todos', 'paid': 'Pago', 'pending': 'Pendente'}, (value) {
        filter.status = value.isEmpty ? null : value;
        onChanged();
      }),
      _drop('Categoria', filter.categoryId, {'': 'Todas', for (final item in categories) item.id: item.name}, (value) {
        filter.categoryId = value.isEmpty ? null : value;
        onChanged();
      }),
      _drop('Conta', filter.accountId, {'': 'Todas', for (final item in accounts) item.id: item.name}, (value) {
        filter.accountId = value.isEmpty ? null : value;
        onChanged();
      }),
      _drop('Cartão', filter.cardId, {'': 'Todos', for (final item in cards) item.id: item.name}, (value) {
        filter.cardId = value.isEmpty ? null : value;
        onChanged();
      }),
    ];
    if (stacked) {
      return Column(
        children: [
          for (final field in fields) ...[
            field,
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return AppCard(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final field in fields)
            SizedBox(width: field is TextField ? 220 : 180, child: field),
        ],
      ),
    );
  }

  Widget _date(BuildContext context, String label, DateTime? value, ValueChanged<DateTime> onPick) {
    return InkWell(
      onTap: () async {
        final picked = await pickDate(context, value ?? DateTime.now());
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(value == null ? 'Qualquer' : formatDay(value)),
      ),
    );
  }

  Widget _drop(String label, String? value, Map<String, String> options, ValueChanged<String> onSelect) {
    return DropdownButtonFormField<String>(
      initialValue: value ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: (selected) => onSelect(selected ?? ''),
    );
  }
}

extension _FirstTx<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
