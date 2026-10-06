import '../core/constants/defaults.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/dates.dart';
import '../core/utils/ids.dart';
import '../core/utils/money.dart';
import '../models/models.dart';

class TxKind {
  static const income = 'income';
  static const expense = 'expense';
  static const cardInstallment = 'cardInstallment';
  static const invoicePayment = 'invoicePayment';
}

class FinanceEngine {
  static void seedCategories(UserBundle bundle) {
    if (bundle.categories.isNotEmpty) return;
    final now = DateTime.now();
    bundle.categories = defaultCategories
        .map(
          (seed) => FinanceCategory(
            id: seed.id,
            userId: bundle.profile.userId,
            name: seed.name,
            kind: seed.kind,
            icon: seed.icon,
            color: seed.color,
            isDefault: true,
            createdAt: now,
            updatedAt: now,
          ),
        )
        .toList();
  }

  static void seedDemo(UserBundle bundle, {DateTime? now}) {
    if (bundle.transactions.isNotEmpty || bundle.transfers.isNotEmpty || bundle.purchases.isNotEmpty) {
      throw const AppException('A demonstração só pode ser carregada em uma conta sem movimentações.');
    }
    seedCategories(bundle);
    final clock = now ?? DateTime.now();
    final previous = DateTime(clock.year, clock.month - 1, 8);
    final uid = bundle.profile.userId;
    final created = DateTime.now();

    bundle.accounts = [
      BankAccount(
        id: 'acc_nubank',
        userId: uid,
        name: 'Nubank',
        bank: 'Nubank',
        type: 'digital',
        initialBalanceCents: 147300,
        balanceCents: 0,
        color: 0xFF7C3AED,
        icon: 'phone',
        createdAt: created,
        updatedAt: created,
      ),
      BankAccount(
        id: 'acc_bb',
        userId: uid,
        name: 'Banco do Brasil',
        bank: 'Banco do Brasil',
        type: 'checking',
        initialBalanceCents: 0,
        balanceCents: 0,
        color: 0xFFCA8A04,
        icon: 'account_balance',
        createdAt: created,
        updatedAt: created,
      ),
      BankAccount(
        id: 'acc_wallet',
        userId: uid,
        name: 'Carteira',
        bank: '',
        type: 'wallet',
        initialBalanceCents: 0,
        balanceCents: 0,
        color: 0xFF059669,
        icon: 'wallet',
        createdAt: created,
        updatedAt: created,
      ),
    ];

    bundle.cards = [
      CreditCardAccount(
        id: 'card_nubank',
        userId: uid,
        name: 'Nubank',
        bank: 'Nubank',
        brand: 'Mastercard',
        limitCents: 500000,
        closingDay: 3,
        dueDay: 10,
        color: 0xFF7C3AED,
        lastFour: '4321',
        createdAt: created,
        updatedAt: created,
      ),
    ];

    void income(String description, int amount, DateTime date, String categoryId, String accountId) {
      addIncome(
        bundle,
        description: description,
        amountCents: amount,
        date: date,
        categoryId: categoryId,
        accountId: accountId,
        silent: true,
      );
    }

    void expense(String description, int amount, DateTime date, String categoryId) {
      addExpense(
        bundle,
        description: description,
        amountCents: amount,
        date: date,
        categoryId: categoryId,
        accountId: 'acc_nubank',
        paymentMethod: 'pix',
        silent: true,
      );
    }

    income('Salário', 700000, DateTime(clock.year, clock.month, 5), 'cat_salary', 'acc_nubank');
    income('Freelance', 250000, DateTime(clock.year, clock.month, 10), 'cat_freelance', 'acc_bb');
    expense('Aluguel', 90000, DateTime(previous.year, previous.month, 8), 'cat_home');
    expense('Mercado', 37300, DateTime(previous.year, previous.month, 12), 'cat_food');
    expense('Combustível', 20000, DateTime(previous.year, previous.month, 18), 'cat_transport');
    expense('Aluguel', 90000, DateTime(clock.year, clock.month, 2), 'cat_home');
    expense('Mercado', 40000, DateTime(clock.year, clock.month, 4), 'cat_food');
    expense('Combustível', 20000, DateTime(clock.year, clock.month, 6), 'cat_transport');
    expense('Internet', 15000, DateTime(clock.year, clock.month, 7), 'cat_subs');
    addTransfer(
      bundle,
      fromAccountId: 'acc_nubank',
      toAccountId: 'acc_wallet',
      amountCents: 30000,
      date: DateTime(clock.year, clock.month, 3),
      notes: 'Dinheiro para a semana',
    );
    addCardPurchase(
      bundle,
      description: 'Notebook',
      amountCents: 185000,
      date: DateTime(clock.year, clock.month, 1),
      cardId: 'card_nubank',
      categoryId: 'cat_shopping',
      installments: 5,
      silent: true,
    );
    addGoal(
      bundle,
      name: 'Comprar carro',
      targetCents: 5000000,
      currentCents: 1850000,
      deadline: DateTime(clock.year + 2, clock.month, 1),
      description: 'Reserva para a entrada do carro',
      icon: 'directions_car',
      color: 0xFF2563EB,
    );
    rebuild(bundle);
  }

  static void upsertAccount(UserBundle bundle, BankAccount account) {
    _requireText(account.name, 'O nome da conta');
    if (!accountTypeLabels.containsKey(account.type)) {
      throw const AppException('Escolha um tipo de conta válido.');
    }
    if (account.initialBalanceCents < 0) {
      throw const AppException('O saldo inicial não pode ser negativo.');
    }
    final index = bundle.accounts.indexWhere((item) => item.id == account.id);
    if (index >= 0) {
      bundle.accounts[index] = account;
    } else {
      bundle.accounts.add(account);
    }
    rebuild(bundle);
  }

  static void deleteAccount(UserBundle bundle, String id) {
    final used = bundle.transactions.any((item) => item.accountId == id) ||
        bundle.transfers.any((item) => item.fromAccountId == id || item.toAccountId == id) ||
        bundle.recurring.any((item) => item.accountId == id);
    if (used) {
      throw const AppException('Esta conta possui movimentações e não pode ser excluída.');
    }
    bundle.accounts.removeWhere((item) => item.id == id);
    rebuild(bundle);
  }

  static void upsertCategory(UserBundle bundle, FinanceCategory category) {
    _requireText(category.name, 'O nome da categoria');
    if (category.kind != 'income' && category.kind != 'expense') {
      throw const AppException('Defina se a categoria é de receita ou despesa.');
    }
    final index = bundle.categories.indexWhere((item) => item.id == category.id);
    if (index >= 0) {
      bundle.categories[index] = category;
    } else {
      bundle.categories.add(category);
    }
  }

  static void deleteCategory(UserBundle bundle, String id) {
    final used = bundle.transactions.any((item) => item.categoryId == id) ||
        bundle.recurring.any((item) => item.categoryId == id) ||
        bundle.purchases.any((item) => item.categoryId == id);
    if (used) {
      throw const AppException('Esta categoria está em uso e não pode ser excluída.');
    }
    bundle.categories.removeWhere((item) => item.id == id);
  }

  static void upsertCard(UserBundle bundle, CreditCardAccount card) {
    _requireText(card.name, 'O nome do cartão');
    if (card.limitCents <= 0) {
      throw const AppException('Informe o limite do cartão.');
    }
    if (card.closingDay < 1 || card.closingDay > 31 || card.dueDay < 1 || card.dueDay > 31) {
      throw const AppException('Informe dias de fechamento e vencimento entre 1 e 31.');
    }
    if (!RegExp(r'^\d{4}$').hasMatch(card.lastFour)) {
      throw const AppException('Informe apenas os 4 últimos dígitos do cartão.');
    }
    final index = bundle.cards.indexWhere((item) => item.id == card.id);
    if (index >= 0) {
      bundle.cards[index] = card;
    } else {
      bundle.cards.add(card);
    }
    rebuild(bundle);
  }

  static void deleteCard(UserBundle bundle, String id) {
    final used = bundle.purchases.any((item) => item.cardId == id) ||
        bundle.transactions.any((item) => item.cardId == id) ||
        bundle.recurring.any((item) => item.cardId == id);
    if (used) {
      throw const AppException('Este cartão possui compras e não pode ser excluído.');
    }
    bundle.cards.removeWhere((item) => item.id == id);
    rebuild(bundle);
  }

  static void addIncome(
    UserBundle bundle, {
    required String description,
    required int amountCents,
    required DateTime date,
    required String categoryId,
    required String accountId,
    String notes = '',
    String status = 'paid',
    bool recurring = false,
    String frequency = 'monthly',
    bool allowDuplicate = false,
    bool silent = false,
    String? recurringId,
    String? periodKey,
    String? id,
  }) {
    _requireText(description, 'A descrição');
    _positive(amountCents);
    final category = _category(bundle, categoryId);
    if (category.kind != 'income') {
      throw const AppException('Escolha uma categoria de receita.');
    }
    _account(bundle, accountId);
    String? linkedRecurring = recurringId;
    var linkedPeriod = periodKey;
    if (recurring) {
      final item = RecurringItem(
        id: newId(),
        userId: bundle.profile.userId,
        name: description.trim(),
        amountCents: amountCents,
        categoryId: categoryId,
        dueDay: date.day.clamp(1, 28),
        dueMonth: date.month,
        accountId: accountId,
        cardId: null,
        frequency: frequencyLabels.containsKey(frequency) ? frequency : 'monthly',
        paymentMethod: 'pix',
        active: true,
        notes: notes.trim(),
        createdAt: date,
        updatedAt: DateTime.now(),
        kind: TxKind.income,
        variable: false,
      );
      bundle.recurring.add(item);
      linkedRecurring = item.id;
      linkedPeriod = periodKeyFor(item, date);
    }
    final fingerprint = fingerprintOf(
      kind: TxKind.income,
      description: description,
      amountCents: amountCents,
      date: date,
      accountId: accountId,
      categoryId: categoryId,
    );
    _ensureUnique(bundle, fingerprint, allowDuplicate);
    final now = DateTime.now();
    final transaction = FinanceTransaction(
      id: id ?? newId(),
      userId: bundle.profile.userId,
      kind: TxKind.income,
      description: description.trim(),
      amountCents: amountCents,
      date: date,
      categoryId: categoryId,
      accountId: accountId,
      cardId: null,
      invoiceId: null,
      purchaseId: null,
      paymentMethod: 'pix',
      notes: notes.trim(),
      status: status,
      recurringId: linkedRecurring,
      periodKey: linkedPeriod,
      installmentNumber: null,
      installmentCount: null,
      fingerprint: fingerprint,
      createdAt: now,
      updatedAt: now,
    );
    bundle.transactions.add(transaction);
    if (!silent) {
      _notify(
        bundle,
        id: 'tx_${transaction.id}',
        title: 'Nova receita cadastrada',
        body: '${transaction.description} • ${formatMoney(amountCents)}',
        type: 'incomeAdded',
      );
    }
    if (recurring) {
      generateRecurring(bundle);
    } else {
      rebuild(bundle);
    }
  }

  static void addExpense(
    UserBundle bundle, {
    required String description,
    required int amountCents,
    required DateTime date,
    required String categoryId,
    required String accountId,
    required String paymentMethod,
    String notes = '',
    String status = 'paid',
    bool recurring = false,
    String frequency = 'monthly',
    bool allowDuplicate = false,
    bool silent = false,
    String? recurringId,
    String? periodKey,
    String? id,
  }) {
    _requireText(description, 'A descrição');
    _positive(amountCents);
    final category = _category(bundle, categoryId);
    if (category.kind != 'expense') {
      throw const AppException('Escolha uma categoria de despesa.');
    }
    _account(bundle, accountId);
    if (!paymentMethodLabels.containsKey(paymentMethod)) {
      throw const AppException('Escolha uma forma de pagamento.');
    }
    String? linkedRecurring = recurringId;
    var linkedPeriod = periodKey;
    if (recurring) {
      final item = RecurringItem(
        id: newId(),
        userId: bundle.profile.userId,
        name: description.trim(),
        amountCents: amountCents,
        categoryId: categoryId,
        dueDay: date.day.clamp(1, 28),
        dueMonth: date.month,
        accountId: accountId,
        cardId: null,
        frequency: frequencyLabels.containsKey(frequency) ? frequency : 'monthly',
        paymentMethod: paymentMethod,
        active: true,
        notes: notes.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      bundle.recurring.add(item);
      linkedRecurring = item.id;
      linkedPeriod = periodKeyFor(item, date);
    }
    final fingerprint = fingerprintOf(
      kind: TxKind.expense,
      description: description,
      amountCents: amountCents,
      date: date,
      accountId: accountId,
      categoryId: categoryId,
    );
    _ensureUnique(bundle, fingerprint, allowDuplicate);
    final now = DateTime.now();
    final transaction = FinanceTransaction(
      id: id ?? newId(),
      userId: bundle.profile.userId,
      kind: TxKind.expense,
      description: description.trim(),
      amountCents: amountCents,
      date: date,
      categoryId: categoryId,
      accountId: accountId,
      cardId: null,
      invoiceId: null,
      purchaseId: null,
      paymentMethod: paymentMethod,
      notes: notes.trim(),
      status: status,
      recurringId: linkedRecurring,
      periodKey: linkedPeriod,
      installmentNumber: null,
      installmentCount: null,
      fingerprint: fingerprint,
      createdAt: now,
      updatedAt: now,
    );
    bundle.transactions.add(transaction);
    if (!silent) {
      _notify(
        bundle,
        id: 'tx_${transaction.id}',
        title: 'Despesa cadastrada',
        body: '${transaction.description} • ${formatMoney(amountCents)}',
        type: 'expenseAdded',
      );
    }
    rebuild(bundle);
  }

  static void setPaymentStatus(UserBundle bundle, String id, String status) {
    if (status != 'paid' && status != 'pending') {
      throw const AppException('Status inválido.');
    }
    final index = bundle.transactions.indexWhere((item) => item.id == id);
    if (index < 0) throw const AppException('Movimentação não encontrada.');
    final current = bundle.transactions[index];
    if (current.kind != TxKind.income && current.kind != TxKind.expense) {
      throw const AppException('Essa movimentação é alterada pelo cartão ou pela fatura.');
    }
    if (current.status == status) return;
    bundle.transactions[index] = current.copyWith(status: status);
    rebuild(bundle);
  }

  static int payPendingExpenses(UserBundle bundle, {DateTime? from, DateTime? to}) {
    var count = 0;
    bundle.transactions = bundle.transactions.map((transaction) {
      if (transaction.kind != TxKind.expense || transaction.status == 'paid') return transaction;
      if (from != null && transaction.date.isBefore(from)) return transaction;
      if (to != null && transaction.date.isAfter(to)) return transaction;
      count++;
      return transaction.copyWith(status: 'paid');
    }).toList();
    if (count == 0) {
      throw const AppException('Não há despesas pendentes neste período.');
    }
    rebuild(bundle);
    return count;
  }

  static void updateTransaction(
    UserBundle bundle, {
    required String id,
    required String description,
    required int amountCents,
    required DateTime date,
    required String categoryId,
    required String? accountId,
    required String? paymentMethod,
    required String notes,
    required String status,
    bool allowDuplicate = false,
  }) {
    final index = bundle.transactions.indexWhere((item) => item.id == id);
    if (index < 0) throw const AppException('Movimentação não encontrada.');
    final current = bundle.transactions[index];
    if (current.kind != TxKind.income && current.kind != TxKind.expense) {
      throw const AppException('Essa movimentação é alterada pelo cartão ou pela fatura.');
    }
    _requireText(description, 'A descrição');
    _positive(amountCents);
    final category = _category(bundle, categoryId);
    if (current.kind == TxKind.income && category.kind != 'income') {
      throw const AppException('Escolha uma categoria de receita.');
    }
    if (current.kind == TxKind.expense && category.kind != 'expense') {
      throw const AppException('Escolha uma categoria de despesa.');
    }
    if (accountId == null) throw const AppException('Escolha uma conta.');
    _account(bundle, accountId);
    final fingerprint = fingerprintOf(
      kind: current.kind,
      description: description,
      amountCents: amountCents,
      date: date,
      accountId: accountId,
      categoryId: categoryId,
    );
    if (bundle.transactions.any((item) => item.fingerprint == fingerprint && item.id != id) && !allowDuplicate) {
      throw const AppException('Já existe uma movimentação igual nessa data.');
    }
    bundle.transactions[index] = current.copyWith(
      description: description.trim(),
      amountCents: amountCents,
      date: date,
      categoryId: categoryId,
      accountId: accountId,
      paymentMethod: paymentMethod,
      notes: notes.trim(),
      status: status,
      fingerprint: fingerprint,
    );
    rebuild(bundle);
  }

  static void deleteTransaction(UserBundle bundle, String id) {
    final transaction = bundle.transactions.where((item) => item.id == id).firstOrNull;
    if (transaction == null) throw const AppException('Movimentação não encontrada.');
    if (transaction.kind == TxKind.cardInstallment) {
      throw const AppException('Exclua a compra do cartão para remover as parcelas.');
    }
    if (transaction.kind == TxKind.invoicePayment) {
      throw const AppException('Desfaça o pagamento pela tela de faturas.');
    }
    bundle.transactions.removeWhere((item) => item.id == id);
    rebuild(bundle);
  }

  static void addCardPurchase(
    UserBundle bundle, {
    required String description,
    required int amountCents,
    required DateTime date,
    required String cardId,
    required String categoryId,
    required int installments,
    String notes = '',
    bool allowDuplicate = false,
    bool silent = false,
    String? purchaseId,
  }) {
    _requireText(description, 'A descrição');
    _positive(amountCents);
    if (installments < 1 || installments > 48) {
      throw const AppException('O parcelamento deve ficar entre 1 e 48 vezes.');
    }
    final card = _card(bundle, cardId);
    final category = _category(bundle, categoryId);
    if (category.kind != 'expense') {
      throw const AppException('Escolha uma categoria de despesa.');
    }
    final used = cardUsedCents(bundle, card.id);
    if (used + amountCents > card.limitCents) {
      throw AppException(
        'Essa compra ultrapassa o limite disponível. Disponível: ${formatMoney(card.limitCents - used)}.',
      );
    }
    final fingerprint = fingerprintOf(
      kind: TxKind.cardInstallment,
      description: description,
      amountCents: amountCents,
      date: date,
      cardId: cardId,
      categoryId: categoryId,
    );
    _ensureUnique(bundle, fingerprint, allowDuplicate);
    final now = DateTime.now();
    final purchase = CardPurchase(
      id: purchaseId ?? newId(),
      userId: bundle.profile.userId,
      description: description.trim(),
      totalCents: amountCents,
      date: date,
      cardId: cardId,
      categoryId: categoryId,
      installments: installments,
      notes: notes.trim(),
      createdAt: now,
      updatedAt: now,
    );
    bundle.purchases.add(purchase);
    bundle.transactions.addAll(_installments(bundle, purchase, card, fingerprint));
    if (!silent) {
      _notify(
        bundle,
        id: 'purchase_${purchase.id}',
        title: 'Compra no cartão',
        body: '${purchase.description} • ${formatMoney(amountCents)} em ${installments}x',
        type: 'expenseAdded',
      );
    }
    rebuild(bundle);
  }

  static void deletePurchase(UserBundle bundle, String id) {
    final purchase = bundle.purchases.where((item) => item.id == id).firstOrNull;
    if (purchase == null) throw const AppException('Compra não encontrada.');
    final invoiceIds = bundle.transactions
        .where((item) => item.purchaseId == id)
        .map((item) => item.invoiceId)
        .whereType<String>()
        .toSet();
    final blocked = bundle.transactions.any(
      (item) => item.kind == TxKind.invoicePayment && item.invoiceId != null && invoiceIds.contains(item.invoiceId),
    );
    if (blocked) {
      throw const AppException('Desfaça o pagamento da fatura antes de excluir esta compra.');
    }
    bundle.transactions.removeWhere((item) => item.purchaseId == id);
    bundle.purchases.removeWhere((item) => item.id == id);
    rebuild(bundle);
  }

  static const ongoingSource = 'carryover';

  static String ongoingPurchaseId(String cardId, int year, int month) => 'ongoing_${cardId}_${year}_$month';

  static List<DateTime> upcomingStatementMonths(int closingDay, {DateTime? from, int count = 12}) {
    final start = statementMonth(from ?? DateTime.now(), closingDay);
    return List<DateTime>.generate(count, (index) => DateTime(start.year, start.month + index, 1));
  }

  /// Grava, em cada fatura, o valor que já estava parcelado antes das compras lançadas no app.
  /// Uma compra nova soma a parcela dela em cima desse valor.
  static void setOngoingAmounts(
    UserBundle bundle, {
    required String cardId,
    required List<({int year, int month, int amountCents})> months,
  }) {
    final card = _card(bundle, cardId);
    final category = bundle.categories.where((item) => item.id == 'cat_expense_other').firstOrNull ??
        bundle.categories.where((item) => item.kind == 'expense').firstOrNull;
    if (category == null) {
      throw const AppException('Cadastre uma categoria de despesa antes de informar os valores.');
    }
    final planned = <String, ({int year, int month, int amountCents})>{};
    for (final month in months) {
      if (month.month < 1 || month.month > 12 || month.year < 2000 || month.year > 2100) {
        throw const AppException('Mês da fatura inválido.');
      }
      if (month.amountCents < 0) {
        throw const AppException('O valor não pode ser negativo.');
      }
      if (month.amountCents > 100000000000) {
        throw const AppException('Valor muito alto.');
      }
      planned['${month.year}-${month.month}'] = month;
    }

    var delta = 0;
    for (final month in planned.values) {
      final id = ongoingPurchaseId(card.id, month.year, month.month);
      final previous = bundle.purchases.where((item) => item.id == id).firstOrNull?.totalCents ?? 0;
      delta += month.amountCents - previous;
      final invoiceId = '${card.id}_${month.year}_${month.month}';
      final paid = _invoicePaid(bundle, invoiceId);
      final total = _invoiceTotal(bundle, invoiceId) - previous + month.amountCents;
      if (paid > total) {
        final label = '${monthNames[month.month - 1]} de ${month.year}';
        throw AppException(
          'A fatura de $label já tem ${formatMoney(paid)} pagos. O novo total ficaria ${formatMoney(total)}.',
        );
      }
    }
    final used = cardUsedCents(bundle, card.id) + delta;
    if (used > card.limitCents) {
      throw AppException(
        'Esses valores passam do limite do cartão. Limite ${formatMoney(card.limitCents)}, ficaria ${formatMoney(used)}.',
      );
    }

    final now = DateTime.now();
    for (final month in planned.values) {
      final id = ongoingPurchaseId(card.id, month.year, month.month);
      final previous = bundle.purchases.where((item) => item.id == id).firstOrNull;
      bundle.purchases.removeWhere((item) => item.id == id);
      bundle.transactions.removeWhere((item) => item.purchaseId == id);
      if (month.amountCents == 0) continue;
      final purchase = CardPurchase(
        id: id,
        userId: bundle.profile.userId,
        description: 'Parcelas em andamento',
        totalCents: month.amountCents,
        date: clampedDate(month.year, month.month, card.closingDay),
        cardId: card.id,
        categoryId: category.id,
        installments: 1,
        notes: '',
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
        source: ongoingSource,
      );
      bundle.purchases.add(purchase);
      bundle.transactions.addAll(_installments(bundle, purchase, card, 'ongoing|$id'));
    }
    rebuild(bundle);
  }

  static void payInvoice(
    UserBundle bundle, {
    required String invoiceId,
    required String accountId,
    required int amountCents,
    required DateTime date,
    String notes = '',
  }) {
    _account(bundle, accountId);
    _positive(amountCents);
    final total = _invoiceTotal(bundle, invoiceId);
    if (total <= 0) throw const AppException('Fatura não encontrada.');
    final paid = _invoicePaid(bundle, invoiceId);
    if (amountCents > total - paid) {
      throw const AppException('O valor é maior que o saldo pendente da fatura.');
    }
    final now = DateTime.now();
    final cardId = bundle.transactions.where((item) => item.invoiceId == invoiceId && item.cardId != null).firstOrNull?.cardId;
    final card = bundle.cards.where((item) => item.id == cardId).firstOrNull;
    final parsed = _parseInvoiceId(invoiceId);
    final monthLabel = parsed.$2 >= 1 && parsed.$2 <= 12 ? monthNames[parsed.$2 - 1] : '';
    final cardName = card == null || card.name.trim().isEmpty ? 'do cartão' : card.name;
    bundle.transactions.add(
      FinanceTransaction(
        id: newId(),
        userId: bundle.profile.userId,
        kind: TxKind.invoicePayment,
        description: 'Fatura $cardName • $monthLabel ${parsed.$1}',
        amountCents: amountCents,
        date: date,
        categoryId: null,
        accountId: accountId,
        cardId: bundle.transactions.where((item) => item.invoiceId == invoiceId).firstOrNull?.cardId,
        invoiceId: invoiceId,
        purchaseId: null,
        paymentMethod: 'transfer',
        notes: notes.trim(),
        status: 'paid',
        recurringId: null,
        periodKey: null,
        installmentNumber: null,
        installmentCount: null,
        fingerprint: 'pay|$invoiceId|${now.microsecondsSinceEpoch}',
        createdAt: now,
        updatedAt: now,
      ),
    );
    rebuild(bundle);
  }

  static void undoInvoicePayment(UserBundle bundle, String invoiceId) {
    final hadPayment = bundle.transactions.any(
      (item) => item.kind == TxKind.invoicePayment && item.invoiceId == invoiceId,
    );
    if (!hadPayment) throw const AppException('Essa fatura não possui pagamento.');
    bundle.transactions.removeWhere(
      (item) => item.kind == TxKind.invoicePayment && item.invoiceId == invoiceId,
    );
    rebuild(bundle);
  }

  static void addTransfer(
    UserBundle bundle, {
    required String fromAccountId,
    required String toAccountId,
    required int amountCents,
    required DateTime date,
    String notes = '',
    String? id,
  }) {
    if (fromAccountId == toAccountId) {
      throw const AppException('Escolha contas diferentes para a transferência.');
    }
    _positive(amountCents);
    _account(bundle, fromAccountId);
    _account(bundle, toAccountId);
    final now = DateTime.now();
    bundle.transfers.add(
      MoneyTransfer(
        id: id ?? newId(),
        userId: bundle.profile.userId,
        fromAccountId: fromAccountId,
        toAccountId: toAccountId,
        amountCents: amountCents,
        date: date,
        notes: notes.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
    rebuild(bundle);
  }

  static void deleteTransfer(UserBundle bundle, String id) {
    final exists = bundle.transfers.any((item) => item.id == id);
    if (!exists) throw const AppException('Transferência não encontrada.');
    bundle.transfers.removeWhere((item) => item.id == id);
    rebuild(bundle);
  }

  static RecurringItem upsertVariableIncome(
    UserBundle bundle, {
    String? id,
    required String name,
    required String categoryId,
    required String accountId,
    required int dueDay,
    String frequency = 'monthly',
    String notes = '',
    bool active = true,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    final item = RecurringItem(
      id: id ?? newId(),
      userId: bundle.profile.userId,
      name: name.trim(),
      amountCents: 0,
      categoryId: categoryId,
      dueDay: dueDay,
      dueMonth: now.month,
      accountId: accountId,
      cardId: null,
      frequency: frequencyLabels.containsKey(frequency) ? frequency : 'monthly',
      paymentMethod: 'pix',
      active: active,
      notes: notes.trim(),
      createdAt: createdAt ?? now,
      updatedAt: now,
      kind: TxKind.income,
      variable: true,
    );
    upsertRecurring(bundle, item);
    return item;
  }

  static void upsertRecurring(UserBundle bundle, RecurringItem item) {
    _requireText(item.name, 'O nome');
    final category = _category(bundle, item.categoryId);
    if (item.variable) {
      if (item.kind != TxKind.income) {
        throw const AppException('Receita variável precisa ser uma receita.');
      }
      if (category.kind != TxKind.income) {
        throw const AppException('Escolha uma categoria de receita.');
      }
      if (item.amountCents < 0) throw const AppException('O valor deve ser maior que zero.');
    } else {
      _positive(item.amountCents);
    }
    if (!frequencyLabels.containsKey(item.frequency)) {
      throw const AppException('Escolha a frequência da conta.');
    }
    if (item.dueDay < 1 || item.dueDay > 28) {
      throw const AppException('O dia de vencimento deve estar entre 1 e 28.');
    }
    if (item.cardId != null) {
      _card(bundle, item.cardId!);
    } else if (item.accountId != null) {
      _account(bundle, item.accountId!);
    } else {
      throw const AppException('Escolha uma conta ou um cartão.');
    }
    final index = bundle.recurring.indexWhere((current) => current.id == item.id);
    if (index >= 0) {
      bundle.recurring[index] = item;
    } else {
      bundle.recurring.add(item);
    }
  }

  static void deleteRecurring(UserBundle bundle, String id) {
    bundle.recurring.removeWhere((item) => item.id == id);
  }

  static void adoptFixedIncomes(UserBundle bundle) {
    if (bundle.profile.fixedIncomesAdopted) return;
    final loose = bundle.transactions.where((transaction) {
      if (transaction.kind != TxKind.income || transaction.recurringId != null) return false;
      if (transaction.accountId == null || transaction.categoryId == null) return false;
      final category = bundle.categories.where((item) => item.id == transaction.categoryId).firstOrNull;
      return category != null && category.kind == TxKind.income;
    }).toList();
    final groups = <String, List<FinanceTransaction>>{};
    for (final transaction in loose) {
      final key = '${transaction.description.trim().toLowerCase()}|${transaction.categoryId}|${transaction.accountId}';
      groups.putIfAbsent(key, () => []).add(transaction);
    }
    for (final group in groups.values) {
      group.sort((a, b) => a.date.compareTo(b.date));
      final latest = group.last;
      final item = RecurringItem(
        id: newId(),
        userId: bundle.profile.userId,
        name: latest.description.trim(),
        amountCents: latest.amountCents,
        categoryId: latest.categoryId!,
        dueDay: latest.date.day.clamp(1, 28),
        dueMonth: latest.date.month,
        accountId: latest.accountId,
        cardId: null,
        frequency: 'monthly',
        paymentMethod: 'pix',
        active: true,
        notes: latest.notes,
        createdAt: group.first.date,
        updatedAt: DateTime.now(),
        kind: TxKind.income,
        variable: false,
      );
      bundle.recurring.add(item);
      final ids = group.map((transaction) => transaction.id).toSet();
      bundle.transactions = bundle.transactions.map((transaction) {
        if (!ids.contains(transaction.id)) return transaction;
        return transaction.copyWith(
          recurringId: item.id,
          periodKey: periodKeyFor(item, transaction.date),
          updateRecurring: true,
        );
      }).toList();
    }
    bundle.profile = bundle.profile.copyWith(fixedIncomesAdopted: true, updatedAt: DateTime.now());
  }

  static void deferCarInsurance(UserBundle bundle, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final index = bundle.recurring.indexWhere(
      (item) => item.name.trim().toLowerCase() == 'seguro do carro' && item.startsOn == null,
    );
    if (index < 0) return;
    final item = bundle.recurring[index];
    final start = clampedDate(clock.year, clock.month + 1, item.dueDay);
    bundle.recurring[index] = RecurringItem(
      id: item.id,
      userId: item.userId,
      name: item.name,
      amountCents: item.amountCents,
      categoryId: item.categoryId,
      dueDay: item.dueDay,
      dueMonth: item.dueMonth,
      accountId: item.accountId,
      cardId: item.cardId,
      frequency: item.frequency,
      paymentMethod: item.paymentMethod,
      active: item.active,
      notes: item.notes,
      createdAt: item.createdAt,
      updatedAt: DateTime.now(),
      kind: item.kind,
      variable: item.variable,
      startsOn: start,
    );
    final name = item.name.trim().toLowerCase();
    bundle.purchases.removeWhere(
      (purchase) => purchase.id.startsWith('rec_${item.id}_') && dateOnly(purchase.date).isBefore(start),
    );
    bundle.transactions.removeWhere((transaction) {
      if (transaction.status == 'paid' || !dateOnly(transaction.date).isBefore(start)) return false;
      if (transaction.recurringId == item.id) return true;
      if (transaction.purchaseId != null && transaction.purchaseId!.startsWith('rec_${item.id}_')) return true;
      return transaction.kind == TxKind.expense && transaction.description.trim().toLowerCase() == name;
    });
  }

  static void generateRecurring(UserBundle bundle, {DateTime? now}) {
    adoptFixedIncomes(bundle);
    deferCarInsurance(bundle, now: now);
    final clock = now ?? DateTime.now();
    final horizon = dateOnly(clock).add(const Duration(days: 35));
    for (final item in List<RecurringItem>.from(bundle.recurring.where((entry) => entry.active && !entry.variable))) {
      for (final date in occurrences(item, horizon, limit: 18)) {
        final key = periodKeyFor(item, date);
        final exists = bundle.transactions.any((tx) => tx.recurringId == item.id && tx.periodKey == key) ||
            bundle.purchases.any((purchase) => purchase.id == 'rec_${item.id}_$key');
        if (exists) continue;
        try {
          if (item.cardId != null) {
            addCardPurchase(
              bundle,
              description: item.name,
              amountCents: item.amountCents,
              date: date,
              cardId: item.cardId!,
              categoryId: item.categoryId,
              installments: 1,
              notes: item.notes,
              allowDuplicate: true,
              silent: true,
              purchaseId: 'rec_${item.id}_$key',
            );
            bundle.transactions = bundle.transactions.map((tx) {
              if (tx.purchaseId != 'rec_${item.id}_$key') return tx;
              return FinanceTransaction(
                id: tx.id,
                userId: tx.userId,
                kind: tx.kind,
                description: tx.description,
                amountCents: tx.amountCents,
                date: tx.date,
                categoryId: tx.categoryId,
                accountId: tx.accountId,
                cardId: tx.cardId,
                invoiceId: tx.invoiceId,
                purchaseId: tx.purchaseId,
                paymentMethod: tx.paymentMethod,
                notes: tx.notes,
                status: tx.status,
                recurringId: item.id,
                periodKey: key,
                installmentNumber: tx.installmentNumber,
                installmentCount: tx.installmentCount,
                fingerprint: tx.fingerprint,
                createdAt: tx.createdAt,
                updatedAt: tx.updatedAt,
              );
            }).toList();
          } else if (item.kind == TxKind.income && item.accountId != null) {
            addIncome(
              bundle,
              description: item.name,
              amountCents: item.amountCents,
              date: date,
              categoryId: item.categoryId,
              accountId: item.accountId!,
              notes: item.notes,
              status: 'pending',
              allowDuplicate: true,
              silent: true,
              recurringId: item.id,
              periodKey: key,
              id: 'rec_${item.id}_$key',
            );
          } else if (item.accountId != null) {
            addExpense(
              bundle,
              description: item.name,
              amountCents: item.amountCents,
              date: date,
              categoryId: item.categoryId,
              accountId: item.accountId!,
              paymentMethod: item.paymentMethod,
              notes: item.notes,
              status: 'pending',
              allowDuplicate: true,
              silent: true,
              recurringId: item.id,
              periodKey: key,
              id: 'rec_${item.id}_$key',
            );
          }
        } on AppException {
          continue;
        }
      }
    }
    rebuild(bundle);
  }

  static void addGoal(
    UserBundle bundle, {
    required String name,
    required int targetCents,
    required int currentCents,
    required DateTime? deadline,
    required String description,
    required String icon,
    required int color,
    String? id,
  }) {
    _requireText(name, 'O nome da meta');
    _positive(targetCents);
    if (currentCents < 0) throw const AppException('O valor atual não pode ser negativo.');
    final now = DateTime.now();
    final goal = FinanceGoal(
      id: id ?? newId(),
      userId: bundle.profile.userId,
      name: name.trim(),
      targetCents: targetCents,
      currentCents: currentCents,
      deadline: deadline,
      description: description.trim(),
      icon: icon,
      color: color,
      createdAt: now,
      updatedAt: now,
    );
    bundle.goals.add(goal);
    _maybeGoalNotification(bundle, 0, goal);
  }

  static void updateGoal(UserBundle bundle, FinanceGoal goal) {
    _requireText(goal.name, 'O nome da meta');
    _positive(goal.targetCents);
    if (goal.currentCents < 0) throw const AppException('O valor atual não pode ser negativo.');
    final index = bundle.goals.indexWhere((item) => item.id == goal.id);
    if (index < 0) throw const AppException('Meta não encontrada.');
    final previous = bundle.goals[index].currentCents;
    bundle.goals[index] = goal;
    _maybeGoalNotification(bundle, previous, goal);
  }

  static void deleteGoal(UserBundle bundle, String id) {
    bundle.goals.removeWhere((item) => item.id == id);
    bundle.notifications.removeWhere((item) => item.id == 'goal_$id');
  }

  static void contributeGoal(UserBundle bundle, String id, int deltaCents) {
    final index = bundle.goals.indexWhere((item) => item.id == id);
    if (index < 0) throw const AppException('Meta não encontrada.');
    final current = bundle.goals[index];
    var next = current.currentCents + deltaCents;
    if (next < 0) next = 0;
    final updated = FinanceGoal(
      id: current.id,
      userId: current.userId,
      name: current.name,
      targetCents: current.targetCents,
      currentCents: next,
      deadline: current.deadline,
      description: current.description,
      icon: current.icon,
      color: current.color,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    bundle.goals[index] = updated;
    _maybeGoalNotification(bundle, current.currentCents, updated);
  }

  static void updateProfile(UserBundle bundle, UserProfile next) {
    if (next.name.trim().length < 3) {
      throw const AppException('Informe o nome completo.');
    }
    if (next.financialMonthStartDay < 1 || next.financialMonthStartDay > 28) {
      throw const AppException('O primeiro dia do mês financeiro deve estar entre 1 e 28.');
    }
    if (next.minimumBalanceCents < 0) {
      throw const AppException('O saldo mínimo não pode ser negativo.');
    }
    final mode = next.themeMode;
    if (mode != 'light' && mode != 'dark' && mode != 'system') {
      throw const AppException('Escolha um tema válido.');
    }
    bundle.profile = next.copyWith(
      email: bundle.profile.email,
      admin: bundle.profile.admin,
      updatedAt: DateTime.now(),
    );
    rebuild(bundle);
  }

  static void changeEmail(UserBundle bundle, String email) {
    bundle.profile = bundle.profile.copyWith(email: email.trim(), updatedAt: DateTime.now());
  }

  static void completeOnboarding(UserBundle bundle) {
    bundle.profile = bundle.profile.copyWith(onboardingCompleted: true, updatedAt: DateTime.now());
  }

  static void markNotificationRead(UserBundle bundle, String id) {
    bundle.notifications = bundle.notifications
        .map((item) => item.id == id ? item.copyWith(read: true) : item)
        .toList();
  }

  static void markAllNotificationsRead(UserBundle bundle) {
    bundle.notifications = bundle.notifications.map((item) => item.copyWith(read: true)).toList();
  }

  static void refreshNotifications(UserBundle bundle, {DateTime? now}) {
    final clock = now ?? DateTime.now();
    final today = dateOnly(clock);
    final total = bundle.accounts.fold(0, (sum, account) => sum + account.balanceCents);
    final lowId = 'low_${today.year}${today.month}${today.day}';
    if (bundle.profile.notifyLowBalance &&
        bundle.profile.minimumBalanceCents > 0 &&
        total < bundle.profile.minimumBalanceCents) {
      _notify(
        bundle,
        id: lowId,
        title: 'Saldo abaixo do limite',
        body: 'Seu saldo está em ${formatMoney(total)}. O mínimo configurado é ${formatMoney(bundle.profile.minimumBalanceCents)}.',
        type: 'lowBalance',
      );
    }

    if (bundle.profile.notifyInvoices) {
      for (final invoice in bundle.invoices.where((item) => item.status != 'paid')) {
        final due = dateOnly(invoice.dueDate);
        final days = due.difference(today).inDays;
        if (days >= 0 && days <= 5) {
          _notify(
            bundle,
            id: 'invoice_${invoice.id}',
            title: 'Fatura próxima do vencimento',
            body: 'Vence em ${formatDay(invoice.dueDate)} • pendente ${formatMoney(invoice.remainingCents)}',
            type: 'invoiceDue',
          );
        }
      }
    }

    if (bundle.profile.notifyBills) {
      for (final item in bundle.recurring.where((entry) => entry.active)) {
        final upcoming = occurrences(item, today.add(const Duration(days: 6)), limit: 4)
            .where((date) => !dateOnly(date).isBefore(today))
            .toList();
        if (upcoming.isEmpty) continue;
        final next = upcoming.first;
        final days = dateOnly(next).difference(today).inDays;
        if (days <= 5) {
          _notify(
            bundle,
            id: 'bill_${item.id}_${periodKeyFor(item, next)}',
            title: item.variable ? 'Receita variável' : 'Conta vencendo',
            body: item.variable
                ? '${item.name} • informe o valor recebido em ${formatDay(next)}'
                : '${item.name} • ${formatMoney(item.amountCents)} em ${formatDay(next)}',
            type: 'billDue',
          );
        }
      }
    }

    if (bundle.profile.notifyGoals) {
      for (final goal in bundle.goals.where((item) => item.currentCents >= item.targetCents)) {
        _notify(
          bundle,
          id: 'goal_${goal.id}',
          title: 'Meta atingida',
          body: '${goal.name} chegou a ${formatMoney(goal.currentCents)}.',
          type: 'goalReached',
        );
      }
    }
  }

  static void rebuild(UserBundle bundle) {
    final invoices = _deriveInvoices(bundle);
    bundle.invoices = invoices;
    final invoiceStatus = {for (final invoice in invoices) invoice.id: invoice.status};
    bundle.transactions = bundle.transactions.map((transaction) {
      if (transaction.kind != TxKind.cardInstallment || transaction.invoiceId == null) {
        return transaction;
      }
      final status = invoiceStatus[transaction.invoiceId] == 'paid' ? 'paid' : 'pending';
      if (transaction.status == status) return transaction;
      return transaction.copyWith(status: status);
    }).toList();
    bundle.accounts = bundle.accounts.map((account) {
      var balance = account.initialBalanceCents;
      for (final transaction in bundle.transactions.where((item) => item.accountId == account.id && item.status == 'paid')) {
        if (transaction.kind == TxKind.income) balance += transaction.amountCents;
        if (transaction.kind == TxKind.expense || transaction.kind == TxKind.invoicePayment) {
          balance -= transaction.amountCents;
        }
      }
      for (final transfer in bundle.transfers) {
        if (transfer.fromAccountId == account.id) balance -= transfer.amountCents;
        if (transfer.toAccountId == account.id) balance += transfer.amountCents;
      }
      return account.copyWith(balanceCents: balance);
    }).toList();
    bundle.summaries = _summaries(bundle);
  }

  static int cardUsedCents(UserBundle bundle, String cardId) {
    final installments = bundle.transactions
        .where((item) => item.kind == TxKind.cardInstallment && item.cardId == cardId)
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final paid = bundle.transactions
        .where((item) => item.kind == TxKind.invoicePayment && item.cardId == cardId)
        .fold<int>(0, (sum, item) => sum + item.amountCents);
    final used = installments - paid;
    return used < 0 ? 0 : used;
  }

  static List<DateTime> occurrences(RecurringItem item, DateTime horizon, {int limit = 18}) {
    var start = dateOnly(item.createdAt);
    if (item.startsOn != null && dateOnly(item.startsOn!).isAfter(start)) {
      start = dateOnly(item.startsOn!);
    }
    final end = dateOnly(horizon);
    final dates = <DateTime>[];
    if (item.frequency == 'weekly') {
      var cursor = start;
      while (cursor.weekday != item.dueDay.clamp(1, 7)) {
        cursor = cursor.add(const Duration(days: 1));
      }
      while (!cursor.isAfter(end) && dates.length < limit) {
        dates.add(cursor);
        cursor = cursor.add(const Duration(days: 7));
      }
      return dates;
    }
    if (item.frequency == 'yearly') {
      for (var year = start.year; year <= end.year && dates.length < limit; year++) {
        final date = clampedDate(year, item.dueMonth.clamp(1, 12), item.dueDay);
        if (!date.isBefore(start) && !date.isAfter(end)) dates.add(date);
      }
      return dates;
    }
    var cursor = DateTime(start.year, start.month, 1);
    while (dates.length < limit) {
      final date = clampedDate(cursor.year, cursor.month, item.dueDay);
      if (date.isAfter(end)) break;
      if (!date.isBefore(start)) dates.add(date);
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }
    return dates;
  }

  static String periodKeyFor(RecurringItem item, DateTime date) {
    if (item.frequency == 'weekly') {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    }
    if (item.frequency == 'yearly') return '${date.year}';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static DateTime statementMonth(DateTime purchase, int closingDay) {
    final closing = clampedDate(purchase.year, purchase.month, closingDay);
    final purchaseDay = dateOnly(purchase);
    if (!purchaseDay.isAfter(dateOnly(closing))) {
      return DateTime(purchase.year, purchase.month, 1);
    }
    return DateTime(purchase.year, purchase.month + 1, 1);
  }

  static List<FinanceTransaction> _installments(
    UserBundle bundle,
    CardPurchase purchase,
    CreditCardAccount card,
    String fingerprint,
  ) {
    final amounts = splitCents(purchase.totalCents, purchase.installments);
    final first = statementMonth(purchase.date, card.closingDay);
    final now = DateTime.now();
    return List<FinanceTransaction>.generate(purchase.installments, (index) {
      final month = DateTime(first.year, first.month + index, 1);
      final date = clampedDate(month.year, month.month, purchase.date.day);
      final label = purchase.installments == 1
          ? purchase.description
          : '${purchase.description} (${index + 1}/${purchase.installments})';
      return FinanceTransaction(
        id: newId(),
        userId: bundle.profile.userId,
        kind: TxKind.cardInstallment,
        description: label,
        amountCents: amounts[index],
        date: date,
        categoryId: purchase.categoryId,
        accountId: null,
        cardId: card.id,
        invoiceId: '${card.id}_${month.year}_${month.month}',
        purchaseId: purchase.id,
        paymentMethod: 'card',
        notes: purchase.notes,
        status: 'pending',
        recurringId: null,
        periodKey: null,
        installmentNumber: index + 1,
        installmentCount: purchase.installments,
        fingerprint: index == 0 ? fingerprint : '$fingerprint|$index',
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  static List<Invoice> _deriveInvoices(UserBundle bundle) {
    final ids = bundle.transactions
        .where((item) => item.kind == TxKind.cardInstallment && item.invoiceId != null)
        .map((item) => item.invoiceId!)
        .toSet();
    final invoices = <Invoice>[];
    for (final id in ids) {
      final parts = bundle.transactions.where((item) => item.invoiceId == id && item.kind == TxKind.cardInstallment);
      final total = parts.fold<int>(0, (sum, item) => sum + item.amountCents);
      final paid = _invoicePaid(bundle, id);
      final cardId = parts.first.cardId ?? '';
      final card = bundle.cards.where((item) => item.id == cardId).firstOrNull;
      final parsed = _parseInvoiceId(id);
      final year = parsed.$1;
      final month = parsed.$2;
      final closingDay = card?.closingDay ?? 1;
      final dueDay = card?.dueDay ?? 10;
      final closing = clampedDate(year, month, closingDay);
      final due = dueDay > closingDay
          ? clampedDate(year, month, dueDay)
          : clampedDate(year, month + 1, dueDay);
      final status = paid <= 0 ? 'open' : (paid >= total ? 'paid' : 'partial');
      final now = DateTime.now();
      invoices.add(
        Invoice(
          id: id,
          userId: bundle.profile.userId,
          cardId: cardId,
          year: year,
          month: month,
          closingDate: closing,
          dueDate: due,
          totalCents: total,
          paidCents: paid > total ? total : paid,
          status: status,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
    invoices.sort((a, b) => (a.year * 100 + a.month).compareTo(b.year * 100 + b.month));
    return invoices;
  }

  static List<MonthSummary> _summaries(UserBundle bundle) {
    final startDay = bundle.profile.financialMonthStartDay;
    final keys = <String>{};
    for (final transaction in bundle.transactions) {
      if (transaction.kind == TxKind.income ||
          transaction.kind == TxKind.expense ||
          transaction.kind == TxKind.cardInstallment ||
          transaction.kind == TxKind.invoicePayment) {
        keys.add(periodOf(transaction.date, startDay).key);
      }
    }
    return keys.map((key) {
      var income = 0;
      var expense = 0;
      var delta = 0;
      final expenseByCategory = <String, int>{};
      final incomeByCategory = <String, int>{};
      final expenseByAccount = <String, int>{};
      final expenseByCard = <String, int>{};
      var topDescription = '';
      var topCents = 0;
      var topCategory = '';
      var pendingExpense = 0;
      for (final transaction in bundle.transactions.where((item) => periodOf(item.date, startDay).key == key)) {
        if (transaction.kind == TxKind.income) {
          income += transaction.amountCents;
          _addMap(incomeByCategory, transaction.categoryId, transaction.amountCents);
          if (transaction.status == 'paid') delta += transaction.amountCents;
        } else if (transaction.kind == TxKind.expense) {
          expense += transaction.amountCents;
          _addMap(expenseByCategory, transaction.categoryId, transaction.amountCents);
          _addMap(expenseByAccount, transaction.accountId, transaction.amountCents);
          if (transaction.amountCents > topCents) {
            topCents = transaction.amountCents;
            topDescription = transaction.description;
            topCategory = transaction.categoryId ?? '';
          }
          if (transaction.status == 'paid') delta -= transaction.amountCents;
          if (transaction.status != 'paid') pendingExpense += transaction.amountCents;
        } else if (transaction.kind == TxKind.cardInstallment) {
          expense += transaction.amountCents;
          _addMap(expenseByCategory, transaction.categoryId, transaction.amountCents);
          _addMap(expenseByCard, transaction.cardId, transaction.amountCents);
          if (transaction.amountCents > topCents) {
            topCents = transaction.amountCents;
            topDescription = transaction.description;
            topCategory = transaction.categoryId ?? '';
          }
        } else if (transaction.kind == TxKind.invoicePayment && transaction.status == 'paid') {
          delta -= transaction.amountCents;
        }
      }
      return MonthSummary(
        id: key,
        userId: bundle.profile.userId,
        incomeCents: income,
        expenseCents: expense,
        balanceDeltaCents: delta,
        expenseByCategory: expenseByCategory,
        incomeByCategory: incomeByCategory,
        expenseByAccount: expenseByAccount,
        expenseByCard: expenseByCard,
        topExpenseDescription: topDescription,
        topExpenseCents: topCents,
        topCategoryId: topCategory,
        pendingExpenseCents: pendingExpense,
      );
    }).toList();
  }

  static void _addMap(Map<String, int> map, String? key, int amount) {
    if (key == null || key.isEmpty) return;
    map[key] = (map[key] ?? 0) + amount;
  }

  static int _invoiceTotal(UserBundle bundle, String invoiceId) {
    return bundle.transactions
        .where((item) => item.kind == TxKind.cardInstallment && item.invoiceId == invoiceId)
        .fold(0, (sum, item) => sum + item.amountCents);
  }

  static int _invoicePaid(UserBundle bundle, String invoiceId) {
    return bundle.transactions
        .where((item) => item.kind == TxKind.invoicePayment && item.invoiceId == invoiceId)
        .fold(0, (sum, item) => sum + item.amountCents);
  }

  static (int, int) _parseInvoiceId(String id) {
    final match = RegExp(r'^(.*)_(\d{4})_(\d{1,2})$').firstMatch(id);
    if (match == null) return (DateTime.now().year, DateTime.now().month);
    return (int.parse(match.group(2)!), int.parse(match.group(3)!));
  }

  static void _ensureUnique(UserBundle bundle, String fingerprint, bool allowDuplicate) {
    if (allowDuplicate) return;
    if (bundle.transactions.any((item) => item.fingerprint == fingerprint)) {
      throw const AppException('Já existe uma movimentação igual nessa data.');
    }
  }

  static void _notify(
    UserBundle bundle, {
    required String id,
    required String title,
    required String body,
    required String type,
  }) {
    if (bundle.notifications.any((item) => item.id == id)) return;
    bundle.notifications.insert(
      0,
      AppNotification(
        id: id,
        userId: bundle.profile.userId,
        title: title,
        body: body,
        type: type,
        read: false,
        createdAt: DateTime.now(),
      ),
    );
  }

  static void _maybeGoalNotification(UserBundle bundle, int previous, FinanceGoal goal) {
    if (!bundle.profile.notifyGoals) return;
    if (previous < goal.targetCents && goal.currentCents >= goal.targetCents) {
      _notify(
        bundle,
        id: 'goal_${goal.id}',
        title: 'Meta atingida',
        body: '${goal.name} chegou a ${formatMoney(goal.currentCents)}.',
        type: 'goalReached',
      );
    }
  }

  static void _requireText(String value, String label) {
    if (value.trim().isEmpty) throw AppException('$label é obrigatório.');
    if (value.trim().length > 120) throw const AppException('O texto está longo demais.');
  }

  static void _positive(int cents) {
    if (cents <= 0) throw const AppException('O valor deve ser maior que zero.');
    if (cents > 100000000000) throw const AppException('Valor muito alto.');
  }

  static BankAccount _account(UserBundle bundle, String id) {
    return bundle.accounts.where((item) => item.id == id).firstOrNull ??
        (throw const AppException('Conta não encontrada.'));
  }

  static FinanceCategory _category(UserBundle bundle, String id) {
    return bundle.categories.where((item) => item.id == id).firstOrNull ??
        (throw const AppException('Categoria não encontrada.'));
  }

  static CreditCardAccount _card(UserBundle bundle, String id) {
    return bundle.cards.where((item) => item.id == id).firstOrNull ??
        (throw const AppException('Cartão não encontrado.'));
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
