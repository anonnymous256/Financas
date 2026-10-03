import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/defaults.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/dates.dart';
import '../core/utils/ids.dart';
import '../core/utils/money.dart';
import '../models/models.dart';
import '../providers/app_providers.dart';
import '../services/finance_engine.dart';
import 'common.dart';

Future<void> _guard(BuildContext context, Future<void> Function() action, {bool close = true}) async {
  try {
    await action();
    if (close && context.mounted) Navigator.pop(context);
  } on AppException catch (error) {
    if (!context.mounted) return;
    if (error.message.contains('igual')) {
      final confirmed = await confirmAction(
        context,
        title: 'Movimentação parecida',
        message: '${error.message} Deseja lançar mesmo assim?',
        confirmLabel: 'Lançar',
      );
      if (!confirmed || !context.mounted) return;
      throw const _DuplicateAllowed();
    }
    showError(context, error.message);
  } catch (error) {
    if (error is _DuplicateAllowed) rethrow;
    if (context.mounted) showError(context, friendlyError(error));
  }
}

class _DuplicateAllowed implements Exception {
  const _DuplicateAllowed();
}

Future<void> showAccountForm(BuildContext context, {BankAccount? existing}) {
  return showAppForm(context, child: AccountForm(existing: existing));
}

class AccountForm extends ConsumerStatefulWidget {
  const AccountForm({super.key, this.existing});

  final BankAccount? existing;

  @override
  ConsumerState<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends ConsumerState<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _bank = TextEditingController(text: widget.existing?.bank ?? '');
  late final _balance = TextEditingController(
    text: widget.existing == null ? '' : (widget.existing!.initialBalanceCents / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  late String _type = widget.existing?.type ?? 'checking';
  late int _color = widget.existing?.color ?? 0xFF0F766E;
  late String _icon = widget.existing?.icon ?? 'account_balance';
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _balance.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final now = DateTime.now();
    final account = BankAccount(
      id: widget.existing?.id ?? newId(),
      userId: ref.read(financeActionsProvider).uid,
      name: _name.text.trim(),
      bank: _bank.text.trim(),
      type: _type,
      initialBalanceCents: parseMoney(_balance.text, allowZero: true),
      balanceCents: widget.existing?.balanceCents ?? 0,
      color: _color,
      icon: _icon,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      FinanceEngine.upsertAccount(bundle, account);
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Nova conta' : 'Editar conta',
      loading: _loading,
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome da conta'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Banco')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: accountTypeLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _balance,
              decoration: const InputDecoration(labelText: 'Saldo inicial', prefixText: 'R\$ '),
              keyboardType: TextInputType.number,
              validator: (value) => validatePositive(value, allowZero: true),
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Cor')),
            const SizedBox(height: 8),
            ColorPicker(value: _color, onChanged: (value) => setState(() => _color = value)),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Ícone')),
            const SizedBox(height: 8),
            IconPicker(value: _icon, color: _color, onChanged: (value) => setState(() => _icon = value)),
          ],
        ),
      ),
    );
  }
}

String? validatePositive(String? value, {bool allowZero = false}) {
  if (value == null || value.trim().isEmpty) return allowZero ? null : 'Informe um valor.';
  try {
    parseMoney(value, allowZero: allowZero);
    return null;
  } on AppException catch (error) {
    return error.message;
  }
}

Future<void> showCategoryForm(BuildContext context, {FinanceCategory? existing, String kind = 'expense'}) {
  return showAppForm(context, child: CategoryForm(existing: existing, kind: kind));
}

class CategoryForm extends ConsumerStatefulWidget {
  const CategoryForm({super.key, this.existing, this.kind = 'expense'});

  final FinanceCategory? existing;
  final String kind;

  @override
  ConsumerState<CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _kind = widget.existing?.kind ?? widget.kind;
  late int _color = widget.existing?.color ?? 0xFF0F766E;
  late String _icon = widget.existing?.icon ?? 'more_horiz';
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final now = DateTime.now();
    final category = FinanceCategory(
      id: widget.existing?.id ?? newId(),
      userId: ref.read(financeActionsProvider).uid,
      name: _name.text.trim(),
      kind: _kind,
      icon: _icon,
      color: _color,
      isDefault: widget.existing?.isDefault ?? false,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      FinanceEngine.upsertCategory(bundle, category);
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Nova categoria' : 'Editar categoria',
      loading: _loading,
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(value: 'income', child: Text('Receita')),
                DropdownMenuItem(value: 'expense', child: Text('Despesa')),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Cor')),
            const SizedBox(height: 8),
            ColorPicker(value: _color, onChanged: (value) => setState(() => _color = value)),
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Ícone')),
            const SizedBox(height: 8),
            IconPicker(value: _icon, color: _color, onChanged: (value) => setState(() => _icon = value)),
          ],
        ),
      ),
    );
  }
}

Future<void> showCardForm(BuildContext context, {CreditCardAccount? existing}) {
  return showAppForm(context, child: CardForm(existing: existing));
}

class CardForm extends ConsumerStatefulWidget {
  const CardForm({super.key, this.existing});

  final CreditCardAccount? existing;

  @override
  ConsumerState<CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<CardForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _bank = TextEditingController(text: widget.existing?.bank ?? '');
  late final _limit = TextEditingController(text: widget.existing == null ? '' : (widget.existing!.limitCents / 100).toStringAsFixed(2).replaceAll('.', ','));
  late final _lastFour = TextEditingController(text: widget.existing?.lastFour ?? '');
  late final _closing = TextEditingController(text: '${widget.existing?.closingDay ?? 1}');
  late final _due = TextEditingController(text: '${widget.existing?.dueDay ?? 10}');
  late String _brand = widget.existing?.brand ?? 'Visa';
  late int _color = widget.existing?.color ?? 0xFF4F46E5;
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _limit.dispose();
    _lastFour.dispose();
    _closing.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final now = DateTime.now();
    final card = CreditCardAccount(
      id: widget.existing?.id ?? newId(),
      userId: ref.read(financeActionsProvider).uid,
      name: _name.text.trim(),
      bank: _bank.text.trim(),
      brand: _brand,
      limitCents: parseMoney(_limit.text),
      closingDay: int.tryParse(_closing.text) ?? 1,
      dueDay: int.tryParse(_due.text) ?? 10,
      color: _color,
      lastFour: _lastFour.text.trim(),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      FinanceEngine.upsertCard(bundle, card);
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Novo cartão' : 'Editar cartão',
      loading: _loading,
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome do cartão'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _bank, decoration: const InputDecoration(labelText: 'Banco')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _brand,
              decoration: const InputDecoration(labelText: 'Bandeira'),
              items: brandLabels.map((brand) => DropdownMenuItem(value: brand, child: Text(brand))).toList(),
              onChanged: (value) => setState(() => _brand = value ?? _brand),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _limit, decoration: const InputDecoration(labelText: 'Limite total', prefixText: 'R\$ '), validator: validatePositive),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastFour,
              decoration: const InputDecoration(labelText: 'Últimos 4 dígitos'),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: (value) => RegExp(r'^\d{4}$').hasMatch(value ?? '') ? null : 'Informe 4 números.',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: TextFormField(controller: _closing, decoration: const InputDecoration(labelText: 'Dia do fechamento'), keyboardType: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _due, decoration: const InputDecoration(labelText: 'Dia do vencimento'), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 16),
            ColorPicker(value: _color, onChanged: (value) => setState(() => _color = value)),
          ],
        ),
      ),
    );
  }
}

Future<void> showOngoingAmountsForm(BuildContext context, CreditCardAccount card) {
  return showAppForm(context, child: OngoingAmountsForm(card: card));
}

class _OngoingRow {
  _OngoingRow({required this.month, required this.extrasCents, required this.controller});

  final DateTime month;
  final int extrasCents;
  final TextEditingController controller;
}

class OngoingAmountsForm extends ConsumerStatefulWidget {
  const OngoingAmountsForm({super.key, required this.card});

  final CreditCardAccount card;

  @override
  ConsumerState<OngoingAmountsForm> createState() => _OngoingAmountsFormState();
}

class _OngoingAmountsFormState extends ConsumerState<OngoingAmountsForm> {
  final _rows = <_OngoingRow>[];
  var _loading = false;

  @override
  void initState() {
    super.initState();
    final purchases = ref.read(purchasesProvider).value ?? const <CardPurchase>[];
    final invoices = ref.read(invoicesProvider).value ?? const <Invoice>[];
    for (final month in FinanceEngine.upcomingStatementMonths(widget.card.closingDay)) {
      final ongoingId = FinanceEngine.ongoingPurchaseId(widget.card.id, month.year, month.month);
      final ongoing = purchases.where((item) => item.id == ongoingId).fold<int>(0, (sum, item) => sum + item.totalCents);
      final invoiceId = '${widget.card.id}_${month.year}_${month.month}';
      final total = invoices.where((item) => item.id == invoiceId).fold<int>(0, (sum, item) => sum + item.totalCents);
      final extras = total - ongoing;
      _rows.add(
        _OngoingRow(
          month: month,
          extrasCents: extras < 0 ? 0 : extras,
          controller: TextEditingController(text: ongoing == 0 ? '' : _moneyInput(ongoing)),
        ),
      );
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final months = _rows
          .map(
            (row) => (
              year: row.month.year,
              month: row.month.month,
              amountCents: _readCents(row.controller.text),
            ),
          )
          .toList();
      await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
        FinanceEngine.setOngoingAmounts(bundle, cardId: widget.card.id, months: months);
      }));
    } on AppException catch (error) {
      if (mounted) showError(context, error.message);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'Valores que já vêm',
      loading: _loading,
      onSubmit: _save,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informe o que já está parcelado em ${widget.card.name}, mês a mês. Quando você lançar uma compra nova, a parcela entra em cima desse valor.',
          ),
          const SizedBox(height: 16),
          ..._rows.map((row) {
            final typed = _tryCents(row.controller.text);
            final invoice = row.extrasCents + typed;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                controller: row.controller,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: '${monthNames[row.month.month - 1]} ${row.month.year}',
                  prefixText: r'R$ ',
                  helperText: row.extrasCents > 0
                      ? 'Compras novas ${formatMoney(row.extrasCents)} • fatura ${formatMoney(invoice)}'
                      : 'Fatura ${formatMoney(invoice)}',
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _moneyInput(int cents) {
  final whole = cents ~/ 100;
  final fraction = (cents % 100).toString().padLeft(2, '0');
  return '$whole,$fraction';
}

int _tryCents(String text) {
  try {
    return _readCents(text);
  } on AppException {
    return 0;
  }
}

int _readCents(String text) {
  if (text.trim().isEmpty) return 0;
  return parseMoney(text, allowZero: true);
}

Future<void> showMovementForm(
  BuildContext context, {
  required String kind,
  FinanceTransaction? existing,
}) {
  return showAppForm(context, child: MovementForm(kind: kind, existing: existing));
}

class MovementForm extends ConsumerStatefulWidget {
  const MovementForm({super.key, required this.kind, this.existing});

  final String kind;
  final FinanceTransaction? existing;

  @override
  ConsumerState<MovementForm> createState() => _MovementFormState();
}

class _MovementFormState extends ConsumerState<MovementForm> {
  final _formKey = GlobalKey<FormState>();
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _amount = TextEditingController(
    text: widget.existing == null ? '' : (widget.existing!.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
  );
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _installments = TextEditingController(text: '1');
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late String _status = widget.existing?.status ?? 'paid';
  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId = widget.existing?.accountId;
  String? _cardId;
  late String _method = widget.existing?.paymentMethod ?? (widget.kind == TxKind.income ? 'pix' : 'pix');
  var _recurring = false;
  var _frequency = 'monthly';
  var _loading = false;

  bool get _isCard => widget.kind == TxKind.expense && _method == 'card' && widget.existing == null;

  Future<void> _save({bool allowDuplicate = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _guard(context, () async {
        await ref.read(financeActionsProvider).run((bundle) {
          if (widget.existing != null) {
            FinanceEngine.updateTransaction(
              bundle,
              id: widget.existing!.id,
              description: _description.text,
              amountCents: parseMoney(_amount.text),
              date: _date,
              categoryId: _categoryId!,
              accountId: _accountId,
              paymentMethod: _method,
              notes: _notes.text,
              status: _status,
              allowDuplicate: allowDuplicate,
            );
            return;
          }
          if (_isCard) {
            FinanceEngine.addCardPurchase(
              bundle,
              description: _description.text,
              amountCents: parseMoney(_amount.text),
              date: _date,
              cardId: _cardId!,
              categoryId: _categoryId!,
              installments: int.tryParse(_installments.text) ?? 1,
              notes: _notes.text,
              allowDuplicate: allowDuplicate,
            );
            return;
          }
          if (widget.kind == TxKind.income) {
            FinanceEngine.addIncome(
              bundle,
              description: _description.text,
              amountCents: parseMoney(_amount.text),
              date: _date,
              categoryId: _categoryId!,
              accountId: _accountId!,
              notes: _notes.text,
              status: _status,
              allowDuplicate: allowDuplicate,
            );
          } else {
            FinanceEngine.addExpense(
              bundle,
              description: _description.text,
              amountCents: parseMoney(_amount.text),
              date: _date,
              categoryId: _categoryId!,
              accountId: _accountId!,
              paymentMethod: _method,
              notes: _notes.text,
              status: _status,
              recurring: _recurring,
              frequency: _frequency,
              allowDuplicate: allowDuplicate,
            );
          }
        });
      });
    } on _DuplicateAllowed {
      if (mounted) await _save(allowDuplicate: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value ?? const <FinanceCategory>[];
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    final cards = ref.watch(cardsProvider).value ?? const <CreditCardAccount>[];
    final filtered = categories.where((item) => item.kind == widget.kind).toList();
    _categoryId ??= filtered.isEmpty ? null : filtered.first.id;
    _accountId ??= accounts.isEmpty ? null : accounts.first.id;
    _cardId ??= cards.isEmpty ? null : cards.first.id;
    final title = widget.existing != null
        ? 'Editar movimentação'
        : widget.kind == TxKind.income
            ? 'Nova receita'
            : 'Nova despesa';
    return FormScaffold(
      title: title,
      loading: _loading,
      onSubmit: () => _save(),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Descrição'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe a descrição.' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '), validator: validatePositive),
            const SizedBox(height: 12),
            DateField(label: 'Data', value: _date, onChanged: (value) => setState(() => _date = value)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: filtered.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
              onChanged: (value) => setState(() => _categoryId = value),
              validator: (value) => value == null ? 'Escolha uma categoria.' : null,
            ),
            const SizedBox(height: 12),
            if (widget.kind == TxKind.expense) ...[
              DropdownButtonFormField<String>(
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                items: paymentMethodLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                onChanged: (value) => setState(() => _method = value ?? _method),
              ),
              const SizedBox(height: 12),
            ],
            if (_isCard)
              DropdownButtonFormField<String>(
                initialValue: _cardId,
                decoration: const InputDecoration(labelText: 'Cartão'),
                items: cards.map((item) => DropdownMenuItem(value: item.id, child: Text('${item.name} • final ${item.lastFour}'))).toList(),
                onChanged: (value) => setState(() => _cardId = value),
                validator: (value) => value == null ? 'Cadastre um cartão.' : null,
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: InputDecoration(labelText: widget.kind == TxKind.income ? 'Conta de destino' : 'Conta'),
                items: accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                onChanged: (value) => setState(() => _accountId = value),
                validator: (value) => value == null ? 'Cadastre uma conta.' : null,
              ),
            if (_isCard) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _installments,
                decoration: const InputDecoration(labelText: 'Número de parcelas'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final count = int.tryParse(value ?? '');
                  if (count == null || count < 1 || count > 48) return 'Use de 1 a 48 parcelas.';
                  return null;
                },
              ),
            ],
            if (widget.existing == null && !_isCard) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conta recorrente?'),
                value: _recurring,
                onChanged: (value) => setState(() => _recurring = value),
              ),
              if (_recurring)
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequência'),
                  items: frequencyLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
                  onChanged: (value) => setState(() => _frequency = value ?? _frequency),
                ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Status'),
              items: const [
                DropdownMenuItem(value: 'paid', child: Text('Pago')),
                DropdownMenuItem(value: 'pending', child: Text('Pendente')),
              ],
              onChanged: _isCard ? null : (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Observação'), maxLines: 3),
          ],
        ),
      ),
    );
  }
}

Future<void> showFundSpendingForm(BuildContext context, BankAccount destination) {
  return showAppForm(context, child: FundSpendingForm(destination: destination));
}

class FundSpendingForm extends ConsumerStatefulWidget {
  const FundSpendingForm({super.key, required this.destination});

  final BankAccount destination;

  @override
  ConsumerState<FundSpendingForm> createState() => _FundSpendingFormState();
}

class _FundSpendingFormState extends ConsumerState<FundSpendingForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  DateTime _date = DateTime.now();
  String? _from;
  var _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accounts = ref.read(accountsProvider).value ?? const <BankAccount>[];
    final origin = accounts.where((item) => item.id == _from).firstOrNull;
    final amount = parseMoney(_amount.text);
    if (origin != null && origin.balanceCents < amount) {
      final ok = await confirmAction(
        context,
        title: 'Saldo insuficiente',
        message: 'Essa transferência deixa ${origin.name} negativa. Deseja continuar?',
        confirmLabel: 'Abastecer',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _loading = true);
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      FinanceEngine.addTransfer(
        bundle,
        fromAccountId: _from!,
        toAccountId: widget.destination.id,
        amountCents: amount,
        date: _date,
        notes: 'Abastecer para gastar',
      );
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    final sources = accounts.where((item) => item.id != widget.destination.id).toList();
    _from ??= sources.isEmpty ? null : sources.first.id;
    return FormScaffold(
      title: 'Abastecer',
      loading: _loading,
      submitLabel: 'Abastecer',
      onSubmit: sources.isEmpty ? null : _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entra em ${widget.destination.name}', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('O valor sai de outra conta. Não conta como despesa nem como receita.'),
            const SizedBox(height: 16),
            if (sources.isEmpty)
              const Text('Cadastre outra conta para abastecer esta.')
            else
              DropdownButtonFormField<String>(
                initialValue: _from,
                decoration: const InputDecoration(labelText: 'Tirar da conta'),
                items: sources
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.name} • ${formatMoney(item.balanceCents, currency: currency)}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _from = value),
                validator: (value) => value == null ? 'Escolha a conta.' : null,
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Valor', prefixText: r'R$ '),
              validator: validatePositive,
            ),
            const SizedBox(height: 12),
            DateField(label: 'Data', value: _date, onChanged: (value) => setState(() => _date = value)),
          ],
        ),
      ),
    );
  }
}

Future<void> showTransferForm(BuildContext context) {
  return showAppForm(context, child: const TransferForm());
}

class TransferForm extends ConsumerStatefulWidget {
  const TransferForm({super.key});

  @override
  ConsumerState<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends ConsumerState<TransferForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  String? _from;
  String? _to;
  var _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final accounts = ref.read(accountsProvider).value ?? const <BankAccount>[];
    final origin = accounts.where((item) => item.id == _from).firstOrNull;
    final amount = parseMoney(_amount.text);
    if (origin != null && origin.balanceCents < amount) {
      final ok = await confirmAction(
        context,
        title: 'Saldo insuficiente',
        message: 'Essa transferência deixa a conta de origem negativa. Deseja continuar?',
        confirmLabel: 'Transferir',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _loading = true);
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      FinanceEngine.addTransfer(
        bundle,
        fromAccountId: _from!,
        toAccountId: _to!,
        amountCents: amount,
        date: _date,
        notes: _notes.text,
      );
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    _from ??= accounts.isEmpty ? null : accounts.first.id;
    _to ??= accounts.length > 1 ? accounts[1].id : _from;
    return FormScaffold(
      title: 'Transferir dinheiro',
      loading: _loading,
      submitLabel: 'Transferir',
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _from,
              decoration: const InputDecoration(labelText: 'Origem'),
              items: accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
              onChanged: (value) => setState(() => _from = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: 'Destino'),
              items: accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
              onChanged: (value) => setState(() => _to = value),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '), validator: validatePositive),
            const SizedBox(height: 12),
            DateField(label: 'Data', value: _date, onChanged: (value) => setState(() => _date = value)),
            const SizedBox(height: 12),
            TextFormField(controller: _notes, decoration: const InputDecoration(labelText: 'Observação')),
          ],
        ),
      ),
    );
  }
}

Future<void> showRecurringForm(BuildContext context, {RecurringItem? existing}) {
  return showAppForm(context, child: RecurringForm(existing: existing));
}

class RecurringForm extends ConsumerStatefulWidget {
  const RecurringForm({super.key, this.existing});

  final RecurringItem? existing;

  @override
  ConsumerState<RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends ConsumerState<RecurringForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _amount = TextEditingController(text: widget.existing == null ? '' : (widget.existing!.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','));
  late final _due = TextEditingController(text: '${widget.existing?.dueDay ?? 5}');
  late String _frequency = widget.existing?.frequency ?? 'monthly';
  late String _method = widget.existing?.paymentMethod ?? 'pix';
  late String? _categoryId = widget.existing?.categoryId;
  late String? _accountId = widget.existing?.accountId;
  late String? _cardId = widget.existing?.cardId;
  late bool _useCard = widget.existing?.cardId != null;
  late bool _active = widget.existing?.active ?? true;
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _due.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final now = DateTime.now();
    final item = RecurringItem(
      id: widget.existing?.id ?? newId(),
      userId: ref.read(financeActionsProvider).uid,
      name: _name.text.trim(),
      amountCents: parseMoney(_amount.text),
      categoryId: _categoryId!,
      dueDay: int.tryParse(_due.text) ?? 1,
      dueMonth: widget.existing?.dueMonth ?? DateTime.now().month,
      accountId: _useCard ? null : _accountId,
      cardId: _useCard ? _cardId : null,
      frequency: _frequency,
      paymentMethod: _method,
      active: _active,
      notes: widget.existing?.notes ?? '',
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      FinanceEngine.upsertRecurring(bundle, item);
      FinanceEngine.generateRecurring(bundle);
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = (ref.watch(categoriesProvider).value ?? const <FinanceCategory>[]).where((item) => item.kind == 'expense').toList();
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    final cards = ref.watch(cardsProvider).value ?? const <CreditCardAccount>[];
    _categoryId ??= categories.isEmpty ? null : categories.first.id;
    _accountId ??= accounts.isEmpty ? null : accounts.first.id;
    _cardId ??= cards.isEmpty ? null : cards.first.id;
    return FormScaffold(
      title: widget.existing == null ? 'Conta recorrente' : 'Editar recorrência',
      loading: _loading,
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _amount, decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '), validator: validatePositive),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequência'),
              items: frequencyLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: (value) => setState(() => _frequency = value ?? _frequency),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _due,
              decoration: InputDecoration(labelText: _frequency == 'weekly' ? 'Dia da semana (1 a 7)' : 'Dia do vencimento'),
              keyboardType: TextInputType.number,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lançar no cartão'),
              value: _useCard,
              onChanged: (value) => setState(() => _useCard = value),
            ),
            if (_useCard)
              DropdownButtonFormField<String>(
                initialValue: _cardId,
                decoration: const InputDecoration(labelText: 'Cartão'),
                items: cards.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                onChanged: (value) => setState(() => _cardId = value),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Conta'),
                items: accounts.map((item) => DropdownMenuItem(value: item.id, child: Text(item.name))).toList(),
                onChanged: (value) => setState(() => _accountId = value),
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(labelText: 'Forma de pagamento'),
              items: paymentMethodLabels.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: (value) => setState(() => _method = value ?? _method),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ativa'),
              value: _active,
              onChanged: (value) => setState(() => _active = value),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showGoalForm(BuildContext context, {FinanceGoal? existing}) {
  return showAppForm(context, child: GoalForm(existing: existing));
}

class GoalForm extends ConsumerStatefulWidget {
  const GoalForm({super.key, this.existing});

  final FinanceGoal? existing;

  @override
  ConsumerState<GoalForm> createState() => _GoalFormState();
}

class _GoalFormState extends ConsumerState<GoalForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(text: widget.existing == null ? '' : (widget.existing!.targetCents / 100).toStringAsFixed(2).replaceAll('.', ','));
  late final _current = TextEditingController(text: widget.existing == null ? '0' : (widget.existing!.currentCents / 100).toStringAsFixed(2).replaceAll('.', ','));
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late DateTime? _deadline = widget.existing?.deadline;
  late String _icon = widget.existing?.icon ?? 'flag';
  late int _color = widget.existing?.color ?? 0xFF0F766E;
  var _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _current.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await _guard(context, () => ref.read(financeActionsProvider).run((bundle) {
      if (widget.existing == null) {
        FinanceEngine.addGoal(
          bundle,
          name: _name.text,
          targetCents: parseMoney(_target.text),
          currentCents: parseMoney(_current.text, allowZero: true),
          deadline: _deadline,
          description: _description.text,
          icon: _icon,
          color: _color,
        );
      } else {
        FinanceEngine.updateGoal(
          bundle,
          FinanceGoal(
            id: widget.existing!.id,
            userId: widget.existing!.userId,
            name: _name.text.trim(),
            targetCents: parseMoney(_target.text),
            currentCents: parseMoney(_current.text, allowZero: true),
            deadline: _deadline,
            description: _description.text.trim(),
            icon: _icon,
            color: _color,
            createdAt: widget.existing!.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }));
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: widget.existing == null ? 'Nova meta' : 'Editar meta',
      loading: _loading,
      onSubmit: _save,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Nome da meta'), validator: (value) => value == null || value.trim().isEmpty ? 'Informe o nome.' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _target, decoration: const InputDecoration(labelText: 'Valor objetivo', prefixText: 'R\$ '), validator: validatePositive),
            const SizedBox(height: 12),
            TextFormField(controller: _current, decoration: const InputDecoration(labelText: 'Valor atual', prefixText: 'R\$ '), validator: (value) => validatePositive(value, allowZero: true)),
            const SizedBox(height: 12),
            DateField(
              label: 'Prazo',
              value: _deadline ?? DateTime.now().add(const Duration(days: 180)),
              onChanged: (value) => setState(() => _deadline = value),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _description, decoration: const InputDecoration(labelText: 'Descrição'), maxLines: 2),
            const SizedBox(height: 16),
            ColorPicker(value: _color, onChanged: (value) => setState(() => _color = value)),
            const SizedBox(height: 12),
            IconPicker(value: _icon, color: _color, onChanged: (value) => setState(() => _icon = value)),
          ],
        ),
      ),
    );
  }
}

Future<String?> showPayInvoiceForm(BuildContext context, Invoice invoice) {
  return showAppForm<String>(context, child: PayInvoiceForm(invoice: invoice));
}

class PayInvoiceForm extends ConsumerStatefulWidget {
  const PayInvoiceForm({super.key, required this.invoice});

  final Invoice invoice;

  @override
  ConsumerState<PayInvoiceForm> createState() => _PayInvoiceFormState();
}

class _PayInvoiceFormState extends ConsumerState<PayInvoiceForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(text: _moneyInput(widget.invoice.remainingCents));
  DateTime _date = DateTime.now();
  String? _accountId;
  var _partial = false;
  var _loading = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _payingCents => _partial ? _tryCents(_amount.text) : widget.invoice.remainingCents;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) {
      showError(context, 'Cadastre uma conta para pagar a fatura.');
      return;
    }
    final amount = _payingCents;
    if (amount <= 0 || amount > widget.invoice.remainingCents) {
      showError(context, 'Informe um valor até o pendente da fatura.');
      return;
    }
    setState(() => _loading = true);
    var saved = false;
    try {
      await ref.read(financeActionsProvider).run((bundle) {
        FinanceEngine.payInvoice(
          bundle,
          invoiceId: widget.invoice.id,
          accountId: _accountId!,
          amountCents: amount,
          date: _date,
        );
      });
      saved = true;
    } on AppException catch (error) {
      if (mounted) showError(context, error.message);
    } catch (error) {
      if (mounted) showError(context, friendlyError(error));
    }
    if (!mounted) return;
    if (saved) {
      final full = amount >= widget.invoice.remainingCents;
      Navigator.pop(context, full ? 'Fatura marcada como paga.' : 'Pagamento registrado.');
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider).value ?? const <BankAccount>[];
    final cards = ref.watch(cardsProvider).value ?? const <CreditCardAccount>[];
    final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
    final card = cards.where((item) => item.id == widget.invoice.cardId).firstOrNull;
    _accountId ??= accounts.isEmpty ? null : accounts.first.id;
    final account = accounts.where((item) => item.id == _accountId).firstOrNull;
    final paying = _payingCents;
    final shortfall = account != null && paying > 0 && account.balanceCents < paying;
    final month = widget.invoice.month >= 1 && widget.invoice.month <= 12 ? monthNames[widget.invoice.month - 1] : '';
    return FormScaffold(
      title: 'Pagar fatura',
      submitLabel: 'Confirmar pagamento',
      loading: _loading,
      onSubmit: accounts.isEmpty ? null : _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${card?.name ?? 'Cartão'} • $month ${widget.invoice.year}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text('Vence ${formatDay(widget.invoice.dueDate)}'),
            const SizedBox(height: 12),
            Text('Total ${formatMoney(widget.invoice.totalCents, currency: currency)}'),
            Text('Já pago ${formatMoney(widget.invoice.paidCents, currency: currency)}'),
            Text(
              'Pendente ${formatMoney(widget.invoice.remainingCents, currency: currency)}',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            if (accounts.isEmpty)
              const Text('Cadastre uma conta para debitar o pagamento.')
            else
              DropdownButtonFormField<String>(
                initialValue: _accountId,
                decoration: const InputDecoration(labelText: 'Sai da conta'),
                items: accounts
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.name} • ${formatMoney(item.balanceCents, currency: currency)}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _accountId = value),
                validator: (value) => value == null ? 'Escolha a conta.' : null,
              ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Pagar só uma parte'),
              value: _partial,
              onChanged: (value) => setState(() => _partial = value),
            ),
            if (_partial)
              TextFormField(
                controller: _amount,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Valor deste pagamento', prefixText: r'R$ '),
                validator: (value) {
                  final cents = _tryCents(value ?? '');
                  if (cents <= 0) return 'Informe um valor.';
                  if (cents > widget.invoice.remainingCents) return 'Maior que o pendente.';
                  return null;
                },
              )
            else
              Text('Será pago ${formatMoney(widget.invoice.remainingCents, currency: currency)}.'),
            const SizedBox(height: 12),
            const Text('O valor sai da conta e libera o mesmo tanto no limite do cartão. Não entra de novo como despesa.'),
            if (shortfall) ...[
              const SizedBox(height: 8),
              Text(
                'O saldo desta conta vai ficar negativo.',
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 12),
            DateField(label: 'Data do pagamento', value: _date, onChanged: (value) => setState(() => _date = value)),
          ],
        ),
      ),
    );
  }
}

extension _FirstForm<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
