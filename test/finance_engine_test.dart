import 'package:financas/core/utils/app_exception.dart';
import 'package:financas/core/utils/dates.dart';
import 'package:financas/core/utils/money.dart';
import 'package:financas/models/models.dart';
import 'package:financas/repositories/local_auth_repository.dart';
import 'package:financas/repositories/local_finance_repository.dart';
import 'package:financas/services/finance_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UserBundle demo() {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(
      userId: 'user-a',
      name: 'Ana Silva',
      email: 'ana@test.com',
    );
    FinanceEngine.seedDemo(bundle, now: DateTime(2026, 10, 3));
    return bundle;
  }

  test('formata e interpreta valores em reais', () {
    expect(formatMoney(785000), 'R\$ 7.850,00');
    expect(formatMoney(-120), '-R\$ 1,20');
    expect(parseMoney('2.500,00'), 250000);
    expect(parseMoney('10,50'), 1050);
    expect(splitCents(185000, 5), [37000, 37000, 37000, 37000, 37000]);
    final invoice = Invoice(
      id: 'card_2026_10',
      userId: 'user-a',
      cardId: 'card',
      year: 2026,
      month: 10,
      closingDate: DateTime(2026, 10, 10),
      dueDate: DateTime(2026, 10, 19),
      totalCents: 16736,
      paidCents: 0,
      status: 'open',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    expect(invoice.remainingCents, 16736);
  });

  test('dados de demonstração fecham o saldo, o cartão e as parcelas', () {
    final bundle = demo();
    expect(bundle.totalBalanceCents, 785000);
    final period = periodOf(DateTime(2026, 10, 3), 1);
    final summary = bundle.summaries.firstWhere((item) => item.id == period.key);
    expect(summary.incomeCents, 950000);
    expect(FinanceEngine.cardUsedCents(bundle, 'card_nubank'), 185000);
    expect(500000 - FinanceEngine.cardUsedCents(bundle, 'card_nubank'), 315000);
    final parts = bundle.transactions.where((item) => item.purchaseId != null);
    expect(parts.length, 5);
    expect(parts.fold<int>(0, (sum, item) => sum + item.amountCents), 185000);
    final goal = bundle.goals.single;
    expect(goal.progress, closeTo(0.37, 0.001));
    final previous = bundle.summaries.firstWhere((item) => item.id == '2026-09');
    expect(percentChange(165000, previous.expenseCents), 12);
  });

  test('pagamento de fatura reduz o saldo e libera limite', () {
    final bundle = demo();
    final invoice = bundle.invoices.firstWhere((item) => item.month == 10 && item.year == 2026);
    final before = bundle.totalBalanceCents;
    FinanceEngine.payInvoice(
      bundle,
      invoiceId: invoice.id,
      accountId: 'acc_nubank',
      amountCents: invoice.totalCents,
      date: DateTime(2026, 10, 10),
    );
    expect(bundle.totalBalanceCents, before - invoice.totalCents);
    expect(FinanceEngine.cardUsedCents(bundle, 'card_nubank'), 185000 - invoice.totalCents);
    final paid = bundle.invoices.firstWhere((item) => item.id == invoice.id);
    expect(paid.status, 'paid');
    expect(paid.remainingCents, 0);
    expect(
      bundle.transactions.where((item) => item.kind == TxKind.invoicePayment).single.description,
      contains('Fatura'),
    );
  });

  test('transferência não altera o patrimônio total', () {
    final bundle = demo();
    final before = bundle.totalBalanceCents;
    final nubank = bundle.accounts.firstWhere((item) => item.id == 'acc_nubank').balanceCents;
    FinanceEngine.addTransfer(
      bundle,
      fromAccountId: 'acc_nubank',
      toAccountId: 'acc_bb',
      amountCents: 50000,
      date: DateTime(2026, 10, 4),
    );
    expect(bundle.totalBalanceCents, before);
    expect(
      bundle.accounts.firstWhere((item) => item.id == 'acc_nubank').balanceCents,
      nubank - 50000,
    );
  });

  test('bloqueia duplicidade e limite do cartão', () {
    final bundle = demo();
    expect(
      () => FinanceEngine.addIncome(
        bundle,
        description: 'Salário',
        amountCents: 700000,
        date: DateTime(2026, 10, 5),
        categoryId: 'cat_salary',
        accountId: 'acc_nubank',
      ),
      throwsA(isA<AppException>()),
    );
    expect(
      () => FinanceEngine.addCardPurchase(
        bundle,
        description: 'Viagem',
        amountCents: 400000,
        date: DateTime(2026, 10, 2),
        cardId: 'card_nubank',
        categoryId: 'cat_leisure',
        installments: 2,
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('valores que já vêm somam com a compra nova', () {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(userId: 'user-a', name: 'Ana Silva', email: 'ana@test.com');
    FinanceEngine.seedCategories(bundle);
    FinanceEngine.upsertCard(
      bundle,
      CreditCardAccount(
        id: 'card_itau',
        userId: 'user-a',
        name: 'Itaú',
        bank: 'Itaú',
        brand: 'Visa',
        limitCents: 500000,
        closingDay: 10,
        dueDay: 17,
        color: 0xFF2563EB,
        lastFour: '1234',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    FinanceEngine.setOngoingAmounts(
      bundle,
      cardId: 'card_itau',
      months: [
        (year: 2026, month: 10, amountCents: 20000),
        (year: 2026, month: 11, amountCents: 15000),
      ],
    );
    FinanceEngine.addCardPurchase(
      bundle,
      description: 'Mercado',
      amountCents: 30000,
      date: DateTime(2026, 10, 2),
      cardId: 'card_itau',
      categoryId: 'cat_food',
      installments: 3,
    );
    int invoice(int month) => bundle.invoices.firstWhere((item) => item.year == 2026 && item.month == month).totalCents;
    expect(invoice(10), 30000);
    expect(invoice(11), 25000);
    expect(invoice(12), 10000);
    expect(FinanceEngine.cardUsedCents(bundle, 'card_itau'), 65000);
  });

  test('pagar despesa recorrente quita o mês e mantém a conta', () {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(userId: 'user-a', name: 'Ana Silva', email: 'ana@test.com');
    FinanceEngine.seedCategories(bundle);
    FinanceEngine.upsertAccount(
      bundle,
      BankAccount(
        id: 'acc_ana',
        userId: 'user-a',
        name: 'Nubank',
        bank: 'Nubank',
        type: 'checking',
        initialBalanceCents: 50000,
        balanceCents: 50000,
        color: 0xFF7C3AED,
        icon: 'account_balance',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    FinanceEngine.addExpense(
      bundle,
      description: 'Internet',
      amountCents: 8000,
      date: DateTime(2026, 10, 25),
      categoryId: 'cat_subs',
      accountId: 'acc_ana',
      paymentMethod: 'pix',
      status: 'pending',
      recurring: true,
    );
    final period = periodOf(DateTime(2026, 10, 3), 1);
    expect(bundle.summaries.firstWhere((item) => item.id == period.key).pendingExpenseCents, 8000);
    expect(bundle.recurring, isNotEmpty);
    FinanceEngine.payPendingExpenses(bundle, from: period.start, to: period.end);
    final paid = bundle.transactions.single;
    expect(paid.status, 'paid');
    expect(paid.recurringId, isNotNull);
    expect(bundle.recurring, isNotEmpty);
    expect(bundle.summaries.firstWhere((item) => item.id == period.key).pendingExpenseCents, 0);
    expect(bundle.accounts.single.balanceCents, 42000);
  });

  test('cada usuário enxerga somente os próprios dados', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final auth = LocalAuthRepository(prefs);
    final finance = LocalFinanceRepository(prefs);
    final ana = await auth.signUp(name: 'Ana Silva', email: 'ana@test.com', password: '123456');
    await finance.ensureUser(ana, name: 'Ana Silva', email: 'ana@test.com');
    await finance.mutate(ana, (bundle) {
      FinanceEngine.upsertAccount(
        bundle,
        BankAccount(
          id: 'acc_ana',
          userId: bundle.profile.userId,
          name: 'Nubank',
          bank: 'Nubank',
          type: 'checking',
          initialBalanceCents: 0,
          balanceCents: 0,
          color: 0xFF7C3AED,
          icon: 'account_balance',
          createdAt: DateTime(2026, 10, 1),
          updatedAt: DateTime(2026, 10, 1),
        ),
      );
      FinanceEngine.addIncome(
        bundle,
        description: 'Salário',
        amountCents: 100000,
        date: DateTime(2026, 10, 5),
        categoryId: 'cat_salary',
        accountId: 'acc_ana',
      );
    });
    await auth.signOut();
    final bruno = await auth.signUp(
      name: 'Bruno Lima',
      email: 'bruno@test.com',
      password: '123456',
    );
    await finance.ensureUser(bruno, name: 'Bruno Lima', email: 'bruno@test.com');
    final brunoData = await finance.readBundle(bruno);
    expect(brunoData!.transactions, isEmpty);
    expect(brunoData.accounts, isEmpty);
    final anaData = await finance.readBundle(ana);
    expect(anaData!.totalBalanceCents, 100000);
    await auth.signOut();
    await auth.signIn(email: 'ana@test.com', password: '123456');
    expect(auth.currentUserId, ana);
    expect(
      () => auth.signIn(email: 'ana@test.com', password: 'errada'),
      throwsA(isA<AppException>()),
    );
  });

  test('receita variável soma mensalidades de valores diferentes', () {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(userId: 'user-a', name: 'Ana Silva', email: 'ana@test.com');
    FinanceEngine.seedCategories(bundle);
    FinanceEngine.upsertAccount(
      bundle,
      BankAccount(
        id: 'acc_ana',
        userId: 'user-a',
        name: 'Nubank',
        bank: 'Nubank',
        type: 'checking',
        initialBalanceCents: 50000,
        balanceCents: 50000,
        color: 0xFF7C3AED,
        icon: 'account_balance',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    final item = FinanceEngine.upsertVariableIncome(
      bundle,
      name: 'Mensalidades',
      categoryId: 'cat_freelance',
      accountId: 'acc_ana',
      dueDay: 10,
    );
    expect(item.variable, isTrue);
    expect(item.kind, TxKind.income);
    expect(item.amountCents, 0);
    final restored = RecurringItem.fromJson(item.toJson());
    expect(restored.variable, isTrue);
    expect(restored.kind, TxKind.income);
    final legacy = RecurringItem.fromJson({
      'id': 'old',
      'userId': 'user-a',
      'name': 'Internet',
      'amountCents': 8000,
      'categoryId': 'cat_subs',
      'dueDay': 5,
      'accountId': 'acc_ana',
      'frequency': 'monthly',
      'paymentMethod': 'pix',
      'active': true,
      'createdAt': DateTime(2026, 10, 1).millisecondsSinceEpoch,
      'updatedAt': DateTime(2026, 10, 1).millisecondsSinceEpoch,
    });
    expect(legacy.variable, isFalse);
    expect(legacy.kind, 'expense');

    FinanceEngine.generateRecurring(bundle, now: DateTime(2026, 10, 20));
    expect(bundle.transactions, isEmpty);

    FinanceEngine.addIncome(
      bundle,
      description: 'Mensalidades • Ana',
      amountCents: 15000,
      date: DateTime(2026, 10, 10),
      categoryId: 'cat_freelance',
      accountId: 'acc_ana',
      recurringId: item.id,
      periodKey: '2026-10',
    );
    FinanceEngine.addIncome(
      bundle,
      description: 'Mensalidades • Bruno',
      amountCents: 22000,
      date: DateTime(2026, 10, 12),
      categoryId: 'cat_freelance',
      accountId: 'acc_ana',
      recurringId: item.id,
      periodKey: '2026-10',
    );
    final period = periodOf(DateTime(2026, 10, 15), 1);
    expect(bundle.summaries.firstWhere((summary) => summary.id == period.key).incomeCents, 37000);
    expect(bundle.accounts.single.balanceCents, 87000);
    expect(bundle.transactions.where((tx) => tx.recurringId == item.id), hasLength(2));
  });

  test('salário recorrente volta pendente no mês seguinte', () {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(userId: 'user-a', name: 'Ana Silva', email: 'ana@test.com');
    FinanceEngine.seedCategories(bundle);
    FinanceEngine.upsertAccount(
      bundle,
      BankAccount(
        id: 'acc_ana',
        userId: 'user-a',
        name: 'Nubank',
        bank: 'Nubank',
        type: 'checking',
        initialBalanceCents: 50000,
        balanceCents: 50000,
        color: 0xFF7C3AED,
        icon: 'account_balance',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    FinanceEngine.addIncome(
      bundle,
      description: 'Salário JS',
      amountCents: 150000,
      date: DateTime(2026, 10, 8),
      categoryId: 'cat_salary',
      accountId: 'acc_ana',
      status: 'paid',
      recurring: true,
      silent: true,
    );
    FinanceEngine.generateRecurring(bundle, now: DateTime(2026, 11, 1));
    final october = bundle.transactions.where((tx) => tx.periodKey == '2026-10').single;
    final november = bundle.transactions.where((tx) => tx.periodKey == '2026-11').single;
    expect(october.status, 'paid');
    expect(october.amountCents, 150000);
    expect(november.status, 'pending');
    expect(november.description, 'Salário JS');
    expect(november.amountCents, 150000);
    expect(november.recurringId, october.recurringId);
    expect(bundle.accounts.single.balanceCents, 200000);
    FinanceEngine.generateRecurring(bundle, now: DateTime(2026, 11, 1));
    expect(bundle.transactions.where((tx) => tx.periodKey == '2026-11'), hasLength(1));
  });

  test('receitas já cadastradas passam a repetir e voltam pendentes', () {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(userId: 'user-a', name: 'Ana Silva', email: 'ana@test.com');
    FinanceEngine.seedCategories(bundle);
    FinanceEngine.upsertAccount(
      bundle,
      BankAccount(
        id: 'acc_ana',
        userId: 'user-a',
        name: 'Nubank',
        bank: 'Nubank',
        type: 'checking',
        initialBalanceCents: 0,
        balanceCents: 0,
        color: 0xFF7C3AED,
        icon: 'account_balance',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    FinanceEngine.addIncome(
      bundle,
      description: 'Salário JS',
      amountCents: 150000,
      date: DateTime(2026, 10, 8),
      categoryId: 'cat_salary',
      accountId: 'acc_ana',
      status: 'paid',
      silent: true,
    );
    expect(bundle.recurring.where((item) => item.kind == TxKind.income && !item.variable), isEmpty);
    FinanceEngine.generateRecurring(bundle, now: DateTime(2026, 11, 1));
    expect(bundle.profile.fixedIncomesAdopted, isTrue);
    final november = bundle.transactions.where((tx) => tx.periodKey == '2026-11').single;
    expect(november.status, 'pending');
    expect(november.description, 'Salário JS');
    expect(bundle.transactions.where((tx) => tx.periodKey == '2026-10').single.status, 'paid');
    expect(bundle.accounts.single.balanceCents, 150000);
  });

  test('seguro do carro fica recorrente só a partir do mês seguinte', () {
    final bundle = UserBundle.empty('user-a');
    bundle.profile = UserProfile.create(userId: 'user-a', name: 'Ana Silva', email: 'ana@test.com');
    bundle.profile = bundle.profile.copyWith(fixedIncomesAdopted: true);
    FinanceEngine.seedCategories(bundle);
    FinanceEngine.upsertAccount(
      bundle,
      BankAccount(
        id: 'acc_ana',
        userId: 'user-a',
        name: 'Conta Salário',
        bank: 'Nubank',
        type: 'checking',
        initialBalanceCents: 0,
        balanceCents: 0,
        color: 0xFF7C3AED,
        icon: 'account_balance',
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
      ),
    );
    final recurring = RecurringItem(
      id: 'seguro',
      userId: 'user-a',
      name: 'Seguro do carro',
      amountCents: 17600,
      categoryId: 'cat_bills',
      dueDay: 10,
      dueMonth: 10,
      accountId: 'acc_ana',
      cardId: null,
      frequency: 'monthly',
      paymentMethod: 'pix',
      active: true,
      notes: '',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 1),
    );
    bundle.recurring.add(recurring);
    FinanceEngine.addExpense(
      bundle,
      description: 'Seguro do carro',
      amountCents: 17600,
      date: DateTime(2026, 10, 10),
      categoryId: 'cat_bills',
      accountId: 'acc_ana',
      paymentMethod: 'pix',
      status: 'pending',
      silent: true,
      recurringId: recurring.id,
      periodKey: '2026-10',
    );
    FinanceEngine.generateRecurring(bundle, now: DateTime(2026, 10, 6));
    expect(bundle.recurring.single.startsOn, DateTime(2026, 11, 10));
    expect(bundle.transactions.where((tx) => tx.periodKey == '2026-10'), isEmpty);
    final november = bundle.transactions.where((tx) => tx.periodKey == '2026-11').single;
    expect(november.description, 'Seguro do carro');
    expect(november.status, 'pending');
    expect(november.amountCents, 17600);
    FinanceEngine.deleteTransaction(bundle, november.id);
    FinanceEngine.generateRecurring(bundle, now: DateTime(2026, 10, 6));
    expect(bundle.transactions.where((tx) => tx.periodKey == '2026-10'), isEmpty);
    expect(bundle.transactions.where((tx) => tx.description == 'Seguro do carro'), hasLength(1));
  });
}
