class JsonMap {
  JsonMap(Map<String, dynamic> raw) : data = Map<String, dynamic>.from(raw);

  final Map<String, dynamic> data;

  String str(String key, [String fallback = '']) => data[key]?.toString() ?? fallback;

  int integer(String key, [int fallback = 0]) {
    final value = data[key];
    if (value is num) return value.toInt();
    return fallback;
  }

  bool boolean(String key, [bool fallback = false]) {
    final value = data[key];
    if (value is bool) return value;
    return fallback;
  }

  DateTime date(String key) =>
      DateTime.fromMillisecondsSinceEpoch(integer(key, DateTime.now().millisecondsSinceEpoch));

  DateTime? optionalDate(String key) {
    final value = data[key];
    if (value == null) return null;
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return null;
  }

  String? optional(String key) {
    final value = data[key];
    if (value == null || value.toString().isEmpty) return null;
    return value.toString();
  }
}

Map<String, int> intMapFrom(dynamic raw) {
  if (raw is! Map) return {};
  return raw.map((key, value) => MapEntry(key.toString(), (value as num).toInt()));
}

class UserProfile {
  const UserProfile({
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    required this.admin,
    required this.onboardingCompleted,
    required this.currency,
    required this.financialMonthStartDay,
    required this.minimumBalanceCents,
    required this.themeMode,
    required this.notifyInvoices,
    required this.notifyBills,
    required this.notifyLowBalance,
    required this.notifyGoals,
    this.spendingAccountId = '',
    this.fixedIncomesAdopted = false,
  });

  factory UserProfile.create({
    required String userId,
    required String name,
    required String email,
  }) {
    final now = DateTime.now();
    return UserProfile(
      userId: userId,
      name: name,
      email: email,
      phone: '',
      photoUrl: '',
      createdAt: now,
      updatedAt: now,
      admin: false,
      onboardingCompleted: false,
      currency: 'BRL',
      financialMonthStartDay: 1,
      minimumBalanceCents: 0,
      themeMode: 'system',
      notifyInvoices: true,
      notifyBills: true,
      notifyLowBalance: true,
      notifyGoals: true,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return UserProfile(
      userId: map.str('userId'),
      name: map.str('name'),
      email: map.str('email'),
      phone: map.str('phone'),
      photoUrl: map.str('photoUrl'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
      admin: map.boolean('admin'),
      onboardingCompleted: map.boolean('onboardingCompleted'),
      currency: map.str('currency', 'BRL'),
      financialMonthStartDay: map.integer('financialMonthStartDay', 1),
      minimumBalanceCents: map.integer('minimumBalanceCents'),
      themeMode: map.str('themeMode', 'system'),
      notifyInvoices: map.boolean('notifyInvoices', true),
      notifyBills: map.boolean('notifyBills', true),
      notifyLowBalance: map.boolean('notifyLowBalance', true),
      notifyGoals: map.boolean('notifyGoals', true),
      spendingAccountId: map.str('spendingAccountId'),
      fixedIncomesAdopted: map.boolean('fixedIncomesAdopted'),
    );
  }

  final String userId;
  final String name;
  final String email;
  final String phone;
  final String photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool admin;
  final bool onboardingCompleted;
  final String currency;
  final int financialMonthStartDay;
  final int minimumBalanceCents;
  final String themeMode;
  final bool notifyInvoices;
  final bool notifyBills;
  final bool notifyLowBalance;
  final bool notifyGoals;
  final String spendingAccountId;
  final bool fixedIncomesAdopted;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'admin': admin,
        'onboardingCompleted': onboardingCompleted,
        'currency': currency,
        'financialMonthStartDay': financialMonthStartDay,
        'minimumBalanceCents': minimumBalanceCents,
        'themeMode': themeMode,
        'notifyInvoices': notifyInvoices,
        'notifyBills': notifyBills,
        'notifyLowBalance': notifyLowBalance,
        'notifyGoals': notifyGoals,
        'spendingAccountId': spendingAccountId,
        'fixedIncomesAdopted': fixedIncomesAdopted,
      };

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    DateTime? updatedAt,
    bool? admin,
    bool? onboardingCompleted,
    String? currency,
    int? financialMonthStartDay,
    int? minimumBalanceCents,
    String? themeMode,
    bool? notifyInvoices,
    bool? notifyBills,
    bool? notifyLowBalance,
    bool? notifyGoals,
    String? spendingAccountId,
    bool? fixedIncomesAdopted,
  }) {
    return UserProfile(
      userId: userId,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      admin: admin ?? this.admin,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      currency: currency ?? this.currency,
      financialMonthStartDay: financialMonthStartDay ?? this.financialMonthStartDay,
      minimumBalanceCents: minimumBalanceCents ?? this.minimumBalanceCents,
      themeMode: themeMode ?? this.themeMode,
      notifyInvoices: notifyInvoices ?? this.notifyInvoices,
      notifyBills: notifyBills ?? this.notifyBills,
      notifyLowBalance: notifyLowBalance ?? this.notifyLowBalance,
      notifyGoals: notifyGoals ?? this.notifyGoals,
      spendingAccountId: spendingAccountId ?? this.spendingAccountId,
      fixedIncomesAdopted: fixedIncomesAdopted ?? this.fixedIncomesAdopted,
    );
  }
}

class BankAccount {
  const BankAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.bank,
    required this.type,
    required this.initialBalanceCents,
    required this.balanceCents,
    required this.color,
    required this.icon,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return BankAccount(
      id: map.str('id'),
      userId: map.str('userId'),
      name: map.str('name'),
      bank: map.str('bank'),
      type: map.str('type', 'checking'),
      initialBalanceCents: map.integer('initialBalanceCents'),
      balanceCents: map.integer('balanceCents'),
      color: map.integer('color', 0xFF0F766E),
      icon: map.str('icon', 'account_balance'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String bank;
  final String type;
  final int initialBalanceCents;
  final int balanceCents;
  final int color;
  final String icon;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'bank': bank,
        'type': type,
        'initialBalanceCents': initialBalanceCents,
        'balanceCents': balanceCents,
        'color': color,
        'icon': icon,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  BankAccount copyWith({int? balanceCents, int? initialBalanceCents}) => BankAccount(
        id: id,
        userId: userId,
        name: name,
        bank: bank,
        type: type,
        initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
        balanceCents: balanceCents ?? this.balanceCents,
        color: color,
        icon: icon,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.userId,
    required this.name,
    required this.kind,
    required this.icon,
    required this.color,
    required this.isDefault,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinanceCategory.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return FinanceCategory(
      id: map.str('id'),
      userId: map.str('userId'),
      name: map.str('name'),
      kind: map.str('kind', 'expense'),
      icon: map.str('icon', 'more_horiz'),
      color: map.integer('color', 0xFF64748B),
      isDefault: map.boolean('isDefault'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String kind;
  final String icon;
  final int color;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'kind': kind,
        'icon': icon,
        'color': color,
        'isDefault': isDefault,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.userId,
    required this.kind,
    required this.description,
    required this.amountCents,
    required this.date,
    required this.categoryId,
    required this.accountId,
    required this.cardId,
    required this.invoiceId,
    required this.purchaseId,
    required this.paymentMethod,
    required this.notes,
    required this.status,
    required this.recurringId,
    required this.periodKey,
    required this.installmentNumber,
    required this.installmentCount,
    required this.fingerprint,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinanceTransaction.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return FinanceTransaction(
      id: map.str('id'),
      userId: map.str('userId'),
      kind: map.str('kind'),
      description: map.str('description'),
      amountCents: map.integer('amountCents'),
      date: map.date('date'),
      categoryId: map.optional('categoryId'),
      accountId: map.optional('accountId'),
      cardId: map.optional('cardId'),
      invoiceId: map.optional('invoiceId'),
      purchaseId: map.optional('purchaseId'),
      paymentMethod: map.optional('paymentMethod'),
      notes: map.str('notes'),
      status: map.str('status', 'paid'),
      recurringId: map.optional('recurringId'),
      periodKey: map.optional('periodKey'),
      installmentNumber: map.data['installmentNumber'] == null ? null : map.integer('installmentNumber'),
      installmentCount: map.data['installmentCount'] == null ? null : map.integer('installmentCount'),
      fingerprint: map.str('fingerprint'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String kind;
  final String description;
  final int amountCents;
  final DateTime date;
  final String? categoryId;
  final String? accountId;
  final String? cardId;
  final String? invoiceId;
  final String? purchaseId;
  final String? paymentMethod;
  final String notes;
  final String status;
  final String? recurringId;
  final String? periodKey;
  final int? installmentNumber;
  final int? installmentCount;
  final String fingerprint;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'kind': kind,
        'description': description,
        'amountCents': amountCents,
        'date': date.millisecondsSinceEpoch,
        'categoryId': categoryId,
        'accountId': accountId,
        'cardId': cardId,
        'invoiceId': invoiceId,
        'purchaseId': purchaseId,
        'paymentMethod': paymentMethod,
        'notes': notes,
        'status': status,
        'recurringId': recurringId,
        'periodKey': periodKey,
        'installmentNumber': installmentNumber,
        'installmentCount': installmentCount,
        'fingerprint': fingerprint,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  FinanceTransaction copyWith({
    String? status,
    String? description,
    String? notes,
    String? categoryId,
    int? amountCents,
    DateTime? date,
    String? accountId,
    String? paymentMethod,
    String? fingerprint,
    String? recurringId,
    String? periodKey,
    bool updateRecurring = false,
  }) {
    return FinanceTransaction(
      id: id,
      userId: userId,
      kind: kind,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      cardId: cardId,
      invoiceId: invoiceId,
      purchaseId: purchaseId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      recurringId: updateRecurring ? recurringId : this.recurringId,
      periodKey: updateRecurring ? periodKey : this.periodKey,
      installmentNumber: installmentNumber,
      installmentCount: installmentCount,
      fingerprint: fingerprint ?? this.fingerprint,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

class CreditCardAccount {
  const CreditCardAccount({
    required this.id,
    required this.userId,
    required this.name,
    required this.bank,
    required this.brand,
    required this.limitCents,
    required this.closingDay,
    required this.dueDay,
    required this.color,
    required this.lastFour,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreditCardAccount.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return CreditCardAccount(
      id: map.str('id'),
      userId: map.str('userId'),
      name: map.str('name'),
      bank: map.str('bank'),
      brand: map.str('brand'),
      limitCents: map.integer('limitCents'),
      closingDay: map.integer('closingDay', 1),
      dueDay: map.integer('dueDay', 10),
      color: map.integer('color', 0xFF4F46E5),
      lastFour: map.str('lastFour'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String name;
  final String bank;
  final String brand;
  final int limitCents;
  final int closingDay;
  final int dueDay;
  final int color;
  final String lastFour;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'bank': bank,
        'brand': brand,
        'limitCents': limitCents,
        'closingDay': closingDay,
        'dueDay': dueDay,
        'color': color,
        'lastFour': lastFour,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class CardPurchase {
  const CardPurchase({
    required this.id,
    required this.userId,
    required this.description,
    required this.totalCents,
    required this.date,
    required this.cardId,
    required this.categoryId,
    required this.installments,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.source = 'purchase',
  });

  factory CardPurchase.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return CardPurchase(
      id: map.str('id'),
      userId: map.str('userId'),
      description: map.str('description'),
      totalCents: map.integer('totalCents'),
      date: map.date('date'),
      cardId: map.str('cardId'),
      categoryId: map.str('categoryId'),
      installments: map.integer('installments', 1),
      notes: map.str('notes'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
      source: map.str('source', 'purchase'),
    );
  }

  final String id;
  final String userId;
  final String description;
  final int totalCents;
  final DateTime date;
  final String cardId;
  final String categoryId;
  final int installments;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'description': description,
        'totalCents': totalCents,
        'date': date.millisecondsSinceEpoch,
        'cardId': cardId,
        'categoryId': categoryId,
        'installments': installments,
        'notes': notes,
        'source': source,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class Invoice {
  const Invoice({
    required this.id,
    required this.userId,
    required this.cardId,
    required this.year,
    required this.month,
    required this.closingDate,
    required this.dueDate,
    required this.totalCents,
    required this.paidCents,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return Invoice(
      id: map.str('id'),
      userId: map.str('userId'),
      cardId: map.str('cardId'),
      year: map.integer('year'),
      month: map.integer('month'),
      closingDate: map.date('closingDate'),
      dueDate: map.date('dueDate'),
      totalCents: map.integer('totalCents'),
      paidCents: map.integer('paidCents'),
      status: map.str('status', 'open'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String cardId;
  final int year;
  final int month;
  final DateTime closingDate;
  final DateTime dueDate;
  final int totalCents;
  final int paidCents;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  int get remainingCents {
    final remaining = totalCents - paidCents;
    if (remaining <= 0) return 0;
    return remaining;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'cardId': cardId,
        'year': year,
        'month': month,
        'closingDate': closingDate.millisecondsSinceEpoch,
        'dueDate': dueDate.millisecondsSinceEpoch,
        'totalCents': totalCents,
        'paidCents': paidCents,
        'status': status,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class MoneyTransfer {
  const MoneyTransfer({
    required this.id,
    required this.userId,
    required this.fromAccountId,
    required this.toAccountId,
    required this.amountCents,
    required this.date,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MoneyTransfer.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return MoneyTransfer(
      id: map.str('id'),
      userId: map.str('userId'),
      fromAccountId: map.str('fromAccountId'),
      toAccountId: map.str('toAccountId'),
      amountCents: map.integer('amountCents'),
      date: map.date('date'),
      notes: map.str('notes'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String fromAccountId;
  final String toAccountId;
  final int amountCents;
  final DateTime date;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'fromAccountId': fromAccountId,
        'toAccountId': toAccountId,
        'amountCents': amountCents,
        'date': date.millisecondsSinceEpoch,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class RecurringItem {
  const RecurringItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.amountCents,
    required this.categoryId,
    required this.dueDay,
    required this.dueMonth,
    required this.accountId,
    required this.cardId,
    required this.frequency,
    required this.paymentMethod,
    required this.active,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.kind = 'expense',
    this.variable = false,
    this.startsOn,
  });

  factory RecurringItem.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return RecurringItem(
      id: map.str('id'),
      userId: map.str('userId'),
      name: map.str('name'),
      amountCents: map.integer('amountCents'),
      categoryId: map.str('categoryId'),
      dueDay: map.integer('dueDay', 1),
      dueMonth: map.integer('dueMonth', 1),
      accountId: map.optional('accountId'),
      cardId: map.optional('cardId'),
      frequency: map.str('frequency', 'monthly'),
      paymentMethod: map.str('paymentMethod', 'pix'),
      active: map.boolean('active', true),
      notes: map.str('notes'),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
      kind: map.str('kind', 'expense'),
      variable: map.boolean('variable'),
      startsOn: map.optionalDate('startsOn'),
    );
  }

  final String id;
  final String userId;
  final String name;
  final int amountCents;
  final String categoryId;
  final int dueDay;
  final int dueMonth;
  final String? accountId;
  final String? cardId;
  final String frequency;
  final String paymentMethod;
  final bool active;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String kind;
  final bool variable;
  final DateTime? startsOn;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'amountCents': amountCents,
        'categoryId': categoryId,
        'dueDay': dueDay,
        'dueMonth': dueMonth,
        'accountId': accountId,
        'cardId': cardId,
        'frequency': frequency,
        'paymentMethod': paymentMethod,
        'active': active,
        'notes': notes,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'kind': kind,
        'variable': variable,
        'startsOn': startsOn?.millisecondsSinceEpoch,
      };
}

class FinanceGoal {
  const FinanceGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetCents,
    required this.currentCents,
    required this.deadline,
    required this.description,
    required this.icon,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FinanceGoal.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return FinanceGoal(
      id: map.str('id'),
      userId: map.str('userId'),
      name: map.str('name'),
      targetCents: map.integer('targetCents'),
      currentCents: map.integer('currentCents'),
      deadline: map.data['deadline'] == null ? null : map.date('deadline'),
      description: map.str('description'),
      icon: map.str('icon', 'flag'),
      color: map.integer('color', 0xFF0F766E),
      createdAt: map.date('createdAt'),
      updatedAt: map.date('updatedAt'),
    );
  }

  final String id;
  final String userId;
  final String name;
  final int targetCents;
  final int currentCents;
  final DateTime? deadline;
  final String description;
  final String icon;
  final int color;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get progress => targetCents <= 0 ? 0 : (currentCents / targetCents).clamp(0, 1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'targetCents': targetCents,
        'currentCents': currentCents,
        'deadline': deadline?.millisecondsSinceEpoch,
        'description': description,
        'icon': icon,
        'color': color,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return AppNotification(
      id: map.str('id'),
      userId: map.str('userId'),
      title: map.str('title'),
      body: map.str('body'),
      type: map.str('type'),
      read: map.boolean('read'),
      createdAt: map.date('createdAt'),
    );
  }

  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'type': type,
        'read': read,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        userId: userId,
        title: title,
        body: body,
        type: type,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}

class MonthSummary {
  const MonthSummary({
    required this.id,
    required this.userId,
    required this.incomeCents,
    required this.expenseCents,
    required this.balanceDeltaCents,
    required this.expenseByCategory,
    required this.incomeByCategory,
    required this.expenseByAccount,
    required this.expenseByCard,
    required this.topExpenseDescription,
    required this.topExpenseCents,
    required this.topCategoryId,
    this.pendingExpenseCents = 0,
  });

  factory MonthSummary.fromJson(Map<String, dynamic> json) {
    final map = JsonMap(json);
    return MonthSummary(
      id: map.str('id'),
      userId: map.str('userId'),
      incomeCents: map.integer('incomeCents'),
      expenseCents: map.integer('expenseCents'),
      balanceDeltaCents: map.integer('balanceDeltaCents'),
      expenseByCategory: intMapFrom(json['expenseByCategory']),
      incomeByCategory: intMapFrom(json['incomeByCategory']),
      expenseByAccount: intMapFrom(json['expenseByAccount']),
      expenseByCard: intMapFrom(json['expenseByCard']),
      topExpenseDescription: map.str('topExpenseDescription'),
      topExpenseCents: map.integer('topExpenseCents'),
      topCategoryId: map.str('topCategoryId'),
      pendingExpenseCents: map.integer('pendingExpenseCents'),
    );
  }

  final String id;
  final String userId;
  final int incomeCents;
  final int expenseCents;
  final int balanceDeltaCents;
  final Map<String, int> expenseByCategory;
  final Map<String, int> incomeByCategory;
  final Map<String, int> expenseByAccount;
  final Map<String, int> expenseByCard;
  final String topExpenseDescription;
  final int topExpenseCents;
  final String topCategoryId;
  final int pendingExpenseCents;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'incomeCents': incomeCents,
        'expenseCents': expenseCents,
        'balanceDeltaCents': balanceDeltaCents,
        'expenseByCategory': expenseByCategory,
        'incomeByCategory': incomeByCategory,
        'expenseByAccount': expenseByAccount,
        'expenseByCard': expenseByCard,
        'topExpenseDescription': topExpenseDescription,
        'topExpenseCents': topExpenseCents,
        'topCategoryId': topCategoryId,
        'pendingExpenseCents': pendingExpenseCents,
      };
}

class UserBundle {
  UserBundle({
    required this.profile,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.cards,
    required this.invoices,
    required this.purchases,
    required this.transfers,
    required this.recurring,
    required this.goals,
    required this.notifications,
    required this.summaries,
  });

  factory UserBundle.empty(String userId) {
    return UserBundle(
      profile: UserProfile.create(userId: userId, name: '', email: ''),
      accounts: [],
      categories: [],
      transactions: [],
      cards: [],
      invoices: [],
      purchases: [],
      transfers: [],
      recurring: [],
      goals: [],
      notifications: [],
      summaries: [],
    );
  }

  factory UserBundle.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      if (raw is! List) return [];
      return raw.whereType<Map>().map((item) => parse(Map<String, dynamic>.from(item))).toList();
    }

    return UserBundle(
      profile: UserProfile.fromJson(Map<String, dynamic>.from(json['profile'] as Map? ?? {})),
      accounts: list('accounts', BankAccount.fromJson),
      categories: list('categories', FinanceCategory.fromJson),
      transactions: list('transactions', FinanceTransaction.fromJson),
      cards: list('cards', CreditCardAccount.fromJson),
      invoices: list('invoices', Invoice.fromJson),
      purchases: list('purchases', CardPurchase.fromJson),
      transfers: list('transfers', MoneyTransfer.fromJson),
      recurring: list('recurring', RecurringItem.fromJson),
      goals: list('goals', FinanceGoal.fromJson),
      notifications: list('notifications', AppNotification.fromJson),
      summaries: list('summaries', MonthSummary.fromJson),
    );
  }

  UserProfile profile;
  List<BankAccount> accounts;
  List<FinanceCategory> categories;
  List<FinanceTransaction> transactions;
  List<CreditCardAccount> cards;
  List<Invoice> invoices;
  List<CardPurchase> purchases;
  List<MoneyTransfer> transfers;
  List<RecurringItem> recurring;
  List<FinanceGoal> goals;
  List<AppNotification> notifications;
  List<MonthSummary> summaries;

  Map<String, dynamic> toJson() => {
        'profile': profile.toJson(),
        'accounts': accounts.map((item) => item.toJson()).toList(),
        'categories': categories.map((item) => item.toJson()).toList(),
        'transactions': transactions.map((item) => item.toJson()).toList(),
        'cards': cards.map((item) => item.toJson()).toList(),
        'invoices': invoices.map((item) => item.toJson()).toList(),
        'purchases': purchases.map((item) => item.toJson()).toList(),
        'transfers': transfers.map((item) => item.toJson()).toList(),
        'recurring': recurring.map((item) => item.toJson()).toList(),
        'goals': goals.map((item) => item.toJson()).toList(),
        'notifications': notifications.map((item) => item.toJson()).toList(),
        'summaries': summaries.map((item) => item.toJson()).toList(),
      };

  UserBundle clone() => UserBundle.fromJson(toJson());

  int get totalBalanceCents => accounts.fold(0, (sum, account) => sum + account.balanceCents);
}

class TxFilter {
  TxFilter({
    this.from,
    this.to,
    this.categoryId,
    this.accountId,
    this.cardId,
    this.kind,
    this.status,
    this.search = '',
    this.page = 1,
    this.pageSize = 8,
  });

  DateTime? from;
  DateTime? to;
  String? categoryId;
  String? accountId;
  String? cardId;
  String? kind;
  String? status;
  String search;
  int page;
  int pageSize;
}

class TxPage {
  const TxPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.truncated,
  });

  final List<FinanceTransaction> items;
  final int total;
  final int page;
  final int pageSize;
  final bool truncated;

  int get pages => total == 0 ? 1 : (total / pageSize).ceil();
}
