import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/query.dart';
import '../models/models.dart';
import 'finance_repository.dart';

class LocalFinanceRepository extends BundleFinanceRepository {
  LocalFinanceRepository(this.prefs);

  final SharedPreferences prefs;
  final Map<String, BehaviorSubject<UserBundle?>> _subjects = {};

  String _key(String uid) => 'fd_bundle_$uid';

  Future<BehaviorSubject<UserBundle?>> _subject(String uid) async {
    final existing = _subjects[uid];
    if (existing != null) return existing;
    final subject = BehaviorSubject<UserBundle?>.seeded(await readBundle(uid));
    _subjects[uid] = subject;
    return subject;
  }

  Stream<UserBundle?> _watch(String uid) async* {
    final subject = await _subject(uid);
    yield* subject.stream;
  }

  @override
  Future<UserBundle?> readBundle(String uid) async {
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final bundle = UserBundle.fromJson(Map<String, dynamic>.from(decoded));
    if (!_containsDemoSeed(bundle)) return bundle;
    bundle.accounts = [];
    bundle.transactions = [];
    bundle.cards = [];
    bundle.invoices = [];
    bundle.purchases = [];
    bundle.transfers = [];
    bundle.recurring = [];
    bundle.goals = [];
    bundle.notifications = [];
    bundle.summaries = [];
    await prefs.setString(_key(uid), jsonEncode(bundle.toJson()));
    return bundle;
  }

  bool _containsDemoSeed(UserBundle bundle) {
    return bundle.accounts.any((account) => account.id == 'acc_nubank') ||
        bundle.cards.any((card) => card.id == 'card_nubank') ||
        bundle.goals.any((goal) => goal.name == 'Comprar carro' && goal.targetCents == 5000000);
  }

  @override
  Future<void> persist(String uid, UserBundle before, UserBundle after) async {
    await prefs.setString(_key(uid), jsonEncode(after.toJson()));
    final subject = _subjects[uid];
    if (subject == null) {
      _subjects[uid] = BehaviorSubject<UserBundle?>.seeded(after);
    } else {
      subject.add(after);
    }
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) => _watch(uid).map((bundle) => bundle?.profile);

  @override
  Stream<List<BankAccount>> watchAccounts(String uid) =>
      _watch(uid).map((bundle) => bundle?.accounts ?? const []);

  @override
  Stream<List<FinanceCategory>> watchCategories(String uid) =>
      _watch(uid).map((bundle) => bundle?.categories ?? const []);

  @override
  Stream<List<CreditCardAccount>> watchCards(String uid) =>
      _watch(uid).map((bundle) => bundle?.cards ?? const []);

  @override
  Stream<List<Invoice>> watchInvoices(String uid) =>
      _watch(uid).map((bundle) => bundle?.invoices ?? const []);

  @override
  Stream<List<MoneyTransfer>> watchTransfers(String uid) =>
      _watch(uid).map((bundle) => bundle?.transfers ?? const []);

  @override
  Stream<List<RecurringItem>> watchRecurring(String uid) =>
      _watch(uid).map((bundle) => bundle?.recurring ?? const []);

  @override
  Stream<List<FinanceGoal>> watchGoals(String uid) =>
      _watch(uid).map((bundle) => bundle?.goals ?? const []);

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) =>
      _watch(uid).map((bundle) => bundle?.notifications ?? const []);

  @override
  Stream<List<MonthSummary>> watchSummaries(String uid) =>
      _watch(uid).map((bundle) => bundle?.summaries ?? const []);

  @override
  Stream<List<CardPurchase>> watchPurchases(String uid) =>
      _watch(uid).map((bundle) => bundle?.purchases ?? const []);

  @override
  Future<TxPage> queryTransactions(String uid, TxFilter filter) async {
    final bundle = await readBundle(uid);
    return paginateTransactions(bundle?.transactions ?? const [], filter);
  }
}
