import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/utils/app_exception.dart';
import '../core/utils/query.dart';
import '../models/models.dart';
import 'finance_repository.dart';

class DocChange {
  const DocChange(this.collection, this.id, this.data);

  final String collection;
  final String id;
  final Map<String, dynamic>? data;
}

class FirestoreFinanceRepository extends BundleFinanceRepository {
  FirestoreFinanceRepository({FirebaseFirestore? firestore})
      : firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore firestore;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      firestore.collection('users').doc(uid);

  @override
  Future<UserBundle?> readBundle(String uid) async {
    try {
      final snapshot = await _user(uid).get();
      if (!snapshot.exists || snapshot.data() == null) return null;
      final bundle = UserBundle.empty(uid);
      bundle.profile = UserProfile.fromJson(snapshot.data()!);
      bundle.accounts = await _load(uid, 'accounts', BankAccount.fromJson);
      bundle.categories = await _load(uid, 'categories', FinanceCategory.fromJson);
      bundle.transactions = await _load(uid, 'transactions', FinanceTransaction.fromJson);
      bundle.cards = await _load(uid, 'cards', CreditCardAccount.fromJson);
      bundle.invoices = await _load(uid, 'invoices', Invoice.fromJson);
      bundle.purchases = await _load(uid, 'purchases', CardPurchase.fromJson);
      bundle.transfers = await _load(uid, 'transfers', MoneyTransfer.fromJson);
      bundle.recurring = await _load(uid, 'recurring_transactions', RecurringItem.fromJson);
      bundle.goals = await _load(uid, 'goals', FinanceGoal.fromJson);
      bundle.notifications = await _load(uid, 'notifications', AppNotification.fromJson);
      bundle.summaries = await _load(uid, 'summaries', MonthSummary.fromJson);
      return bundle;
    } on FirebaseException catch (error) {
      throw AppException(_firebaseMessage(error));
    }
  }

  Future<List<T>> _load<T>(
    String uid,
    String collection,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final snapshot = await _user(uid).collection(collection).get();
    return snapshot.docs.map((doc) => parse(doc.data())).toList();
  }

  @override
  Future<void> persist(String uid, UserBundle before, UserBundle after) async {
    try {
      final changes = diffBundles(before, after);
      await _commit(uid, after.profile.toJson(), changes);
    } on FirebaseException catch (error) {
      throw AppException(_firebaseMessage(error));
    }
  }

  Future<void> _commit(String uid, Map<String, dynamic> profile, List<DocChange> changes) async {
    WriteBatch batch = firestore.batch();
    var operations = 0;

    Future<void> flush() async {
      if (operations == 0) return;
      await batch.commit();
      batch = firestore.batch();
      operations = 0;
    }

    batch.set(_user(uid), profile);
    operations++;
    for (final change in changes) {
      final ref = _user(uid).collection(change.collection).doc(change.id);
      if (change.data == null) {
        batch.delete(ref);
      } else {
        batch.set(ref, change.data!);
      }
      operations++;
      if (operations >= 400) await flush();
    }
    await flush();
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _user(uid).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return UserProfile.fromJson(snapshot.data()!);
    });
  }

  @override
  Stream<List<BankAccount>> watchAccounts(String uid) =>
      _watch(uid, 'accounts', BankAccount.fromJson);

  @override
  Stream<List<FinanceCategory>> watchCategories(String uid) =>
      _watch(uid, 'categories', FinanceCategory.fromJson);

  @override
  Stream<List<CreditCardAccount>> watchCards(String uid) =>
      _watch(uid, 'cards', CreditCardAccount.fromJson);

  @override
  Stream<List<Invoice>> watchInvoices(String uid) =>
      _watch(uid, 'invoices', Invoice.fromJson);

  @override
  Stream<List<MoneyTransfer>> watchTransfers(String uid) =>
      _watch(uid, 'transfers', MoneyTransfer.fromJson);

  @override
  Stream<List<RecurringItem>> watchRecurring(String uid) =>
      _watch(uid, 'recurring_transactions', RecurringItem.fromJson);

  @override
  Stream<List<FinanceGoal>> watchGoals(String uid) => _watch(uid, 'goals', FinanceGoal.fromJson);

  @override
  Stream<List<AppNotification>> watchNotifications(String uid) =>
      _watch(uid, 'notifications', AppNotification.fromJson);

  @override
  Stream<List<MonthSummary>> watchSummaries(String uid) =>
      _watch(uid, 'summaries', MonthSummary.fromJson);

  @override
  Stream<List<CardPurchase>> watchPurchases(String uid) =>
      _watch(uid, 'purchases', CardPurchase.fromJson);

  Stream<List<T>> _watch<T>(
    String uid,
    String collection,
    T Function(Map<String, dynamic>) parse,
  ) {
    return _user(uid).collection(collection).snapshots().map(
          (snapshot) => snapshot.docs.map((doc) => parse(doc.data())).toList(),
        );
  }

  @override
  Future<TxPage> queryTransactions(String uid, TxFilter filter) async {
    try {
      Query<Map<String, dynamic>> query =
          _user(uid).collection('transactions').orderBy('date', descending: true);
      if (filter.from != null) {
        query = query.where('date', isGreaterThanOrEqualTo: filter.from!.millisecondsSinceEpoch);
      }
      if (filter.to != null) {
        query = query.where('date', isLessThanOrEqualTo: filter.to!.millisecondsSinceEpoch);
      }
      final snapshot = await query.limit(500).get();
      final items = snapshot.docs.map((doc) => FinanceTransaction.fromJson(doc.data())).toList();
      return paginateTransactions(items, filter, truncated: snapshot.docs.length >= 500);
    } on FirebaseException catch (error) {
      throw AppException(_firebaseMessage(error));
    }
  }
}

List<DocChange> diffBundles(UserBundle before, UserBundle after) {
  final changes = <DocChange>[];

  void collection(
    String name,
    List<Map<String, dynamic>> previous,
    List<Map<String, dynamic>> next,
  ) {
    final previousMap = {for (final item in previous) item['id'].toString(): item};
    final nextMap = {for (final item in next) item['id'].toString(): item};
    for (final entry in nextMap.entries) {
      final old = previousMap[entry.key];
      if (old == null || jsonEncode(old) != jsonEncode(entry.value)) {
        changes.add(DocChange(name, entry.key, entry.value));
      }
    }
    for (final id in previousMap.keys) {
      if (!nextMap.containsKey(id)) changes.add(DocChange(name, id, null));
    }
  }

  collection('accounts', _maps(before.accounts), _maps(after.accounts));
  collection('categories', _maps(before.categories), _maps(after.categories));
  collection('transactions', _maps(before.transactions), _maps(after.transactions));
  collection('cards', _maps(before.cards), _maps(after.cards));
  collection('invoices', _maps(before.invoices), _maps(after.invoices));
  collection('purchases', _maps(before.purchases), _maps(after.purchases));
  collection('transfers', _maps(before.transfers), _maps(after.transfers));
  collection('recurring_transactions', _maps(before.recurring), _maps(after.recurring));
  collection('goals', _maps(before.goals), _maps(after.goals));
  collection('notifications', _maps(before.notifications), _maps(after.notifications));
  collection('summaries', _maps(before.summaries), _maps(after.summaries));
  return changes;
}

List<Map<String, dynamic>> _maps(List<dynamic> items) =>
    items.map((item) => item.toJson() as Map<String, dynamic>).toList();

String _firebaseMessage(FirebaseException error) {
  switch (error.code) {
    case 'permission-denied':
      return 'Você não tem permissão para acessar esses dados.';
    case 'unavailable':
    case 'network-request-failed':
      return 'Sem conexão com a internet.';
    case 'not-found':
      return 'Não encontramos esse registro.';
    case 'deadline-exceeded':
      return 'A conexão demorou demais. Tente novamente.';
    default:
      return 'Não foi possível falar com o servidor. Tente novamente.';
  }
}
