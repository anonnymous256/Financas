import 'dart:async';

import '../models/models.dart';
import '../services/finance_engine.dart';

abstract class FinanceRepository {
  Stream<UserProfile?> watchProfile(String uid);
  Stream<List<BankAccount>> watchAccounts(String uid);
  Stream<List<FinanceCategory>> watchCategories(String uid);
  Stream<List<CreditCardAccount>> watchCards(String uid);
  Stream<List<Invoice>> watchInvoices(String uid);
  Stream<List<MoneyTransfer>> watchTransfers(String uid);
  Stream<List<RecurringItem>> watchRecurring(String uid);
  Stream<List<FinanceGoal>> watchGoals(String uid);
  Stream<List<AppNotification>> watchNotifications(String uid);
  Stream<List<MonthSummary>> watchSummaries(String uid);
  Stream<List<CardPurchase>> watchPurchases(String uid);

  Future<UserBundle?> readBundle(String uid);
  Future<void> ensureUser(String uid, {required String name, required String email});
  Future<void> mutate(String uid, void Function(UserBundle bundle) change);
  Future<TxPage> queryTransactions(String uid, TxFilter filter);
}

abstract class BundleFinanceRepository implements FinanceRepository {
  final Map<String, Future<void>> _tails = {};

  Future<void> persist(String uid, UserBundle before, UserBundle after);

  @override
  Future<void> ensureUser(String uid, {required String name, required String email}) async {
    final existing = await readBundle(uid);
    if (existing != null && existing.profile.userId == uid && existing.profile.email.isNotEmpty) {
      if (existing.categories.isEmpty) {
        await mutate(uid, FinanceEngine.seedCategories);
      }
      return;
    }
    await mutate(uid, (bundle) {
      final safeName = name.trim().length < 3 ? 'Usuário' : name.trim();
      bundle.profile = UserProfile.create(
        userId: uid,
        name: safeName,
        email: email.trim().toLowerCase(),
      );
      FinanceEngine.seedCategories(bundle);
    });
  }

  @override
  Future<void> mutate(String uid, void Function(UserBundle bundle) change) {
    final previous = _tails[uid] ?? Future<void>.value();
    final operation = previous.then((_) async {
      final current = await readBundle(uid) ?? UserBundle.empty(uid);
      final next = current.clone();
      change(next);
      final profile = next.profile.toJson();
      profile['userId'] = uid;
      profile['admin'] = current.profile.admin;
      next.profile = UserProfile.fromJson(profile);
      FinanceEngine.rebuild(next);
      await persist(uid, current, next);
    });
    _tails[uid] = operation.then((_) {}, onError: (_) {});
    return operation;
  }
}
