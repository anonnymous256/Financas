import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_exception.dart';
import '../core/utils/money.dart';
import '../models/models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/finance_repository.dart';
import '../repositories/firebase_auth_repository.dart';
import '../repositories/firestore_finance_repository.dart';
import '../repositories/local_auth_repository.dart';
import '../repositories/local_finance_repository.dart';
final firebaseReadyProvider = Provider<bool>((ref) => false);

final prefsProvider = Provider<SharedPreferences>((ref) {
  throw StateError('SharedPreferences não iniciado');
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  if (ref.watch(firebaseReadyProvider)) return FirebaseAuthRepository();
  return LocalAuthRepository(ref.watch(prefsProvider));
});

final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  if (ref.watch(firebaseReadyProvider)) return FirestoreFinanceRepository();
  return LocalFinanceRepository(ref.watch(prefsProvider));
});

final authStateProvider = StreamProvider<String?>((ref) {
  return ref.watch(authRepositoryProvider).authState();
});

final profileProvider = StreamProvider<UserProfile?>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream<UserProfile?>.value(null);
  return ref.watch(financeRepositoryProvider).watchProfile(uid);
});

final accountsProvider = StreamProvider<List<BankAccount>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchAccounts(uid);
});

final categoriesProvider = StreamProvider<List<FinanceCategory>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchCategories(uid);
});

final cardsProvider = StreamProvider<List<CreditCardAccount>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchCards(uid);
});

final invoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchInvoices(uid);
});

final transfersProvider = StreamProvider<List<MoneyTransfer>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchTransfers(uid);
});

final recurringProvider = StreamProvider<List<RecurringItem>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchRecurring(uid);
});

final goalsProvider = StreamProvider<List<FinanceGoal>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchGoals(uid);
});

final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchNotifications(uid);
});

final summariesProvider = StreamProvider<List<MonthSummary>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchSummaries(uid);
});

final purchasesProvider = StreamProvider<List<CardPurchase>>((ref) {
  final uid = ref.watch(authStateProvider).value;
  if (uid == null) return Stream.value(const []);
  return ref.watch(financeRepositoryProvider).watchPurchases(uid);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  return switch (ref.watch(profileProvider).value?.themeMode) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
});

class RevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final revisionProvider = NotifierProvider<RevisionNotifier, int>(RevisionNotifier.new);

class FinanceActions {
  FinanceActions(this.ref);

  final Ref ref;

  String get uid {
    final id = ref.read(authStateProvider).value;
    if (id == null) {
      throw const AppException('Sua sessão expirou. Entre novamente.');
    }
    return id;
  }

  Future<void> run(void Function(UserBundle bundle) change) async {
    await ref.read(financeRepositoryProvider).mutate(uid, change);
    ref.read(revisionProvider.notifier).bump();
  }
}

final financeActionsProvider = Provider<FinanceActions>((ref) => FinanceActions(ref));

class SessionController {
  SessionController(this.ref);

  final Ref ref;

  Future<void> signIn({required String email, required String password}) async {
    final auth = ref.read(authRepositoryProvider);
    final uid = await auth.signIn(email: email, password: password);
    await ref.read(financeRepositoryProvider).ensureUser(
          uid,
          name: auth.currentName ?? 'Usuário',
          email: auth.currentEmail ?? email,
        );
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final auth = ref.read(authRepositoryProvider);
    final uid = await auth.signUp(name: name, email: email, password: password);
    await ref.read(financeRepositoryProvider).ensureUser(uid, name: name, email: email);
  }

  Future<void> signOut() => ref.read(authRepositoryProvider).signOut();
}

final sessionControllerProvider = Provider<SessionController>((ref) => SessionController(ref));

String moneyOf(WidgetRef ref, int cents) {
  final currency = ref.watch(profileProvider).value?.currency ?? 'BRL';
  return formatMoney(cents, currency: currency);
}
