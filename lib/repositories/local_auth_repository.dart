import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/utils/app_exception.dart';
import '../core/utils/ids.dart';
import '../core/utils/validators.dart';
import 'auth_repository.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this.prefs);

  final SharedPreferences prefs;
  final _changes = StreamController<String?>.broadcast();

  static const _usersKey = 'fd_auth_users';
  static const _sessionKey = 'fd_session';
  static const _resetsKey = 'fd_resets';

  @override
  bool get sendsResetEmail => false;

  @override
  Stream<String?> authState() async* {
    yield prefs.getString(_sessionKey);
    yield* _changes.stream;
  }

  @override
  String? get currentUserId => prefs.getString(_sessionKey);

  @override
  String? get currentEmail => _current()?['email'] as String?;

  @override
  String? get currentName => _current()?['name'] as String?;

  @override
  Future<String> signIn({required String email, required String password}) async {
    final emailError = validateEmail(email);
    if (emailError != null) throw AppException(emailError);
    final passwordError = validatePassword(password);
    if (passwordError != null) throw AppException(passwordError);
    final user = _find(email);
    if (user == null) {
      throw const AppException('Não encontramos uma conta com esse e-mail.');
    }
    if (user['hash'] != _hash(user['salt'] as String, password)) {
      throw const AppException('Senha incorreta.');
    }
    await prefs.setString(_sessionKey, user['id'] as String);
    _changes.add(user['id'] as String);
    return user['id'] as String;
  }

  @override
  Future<String> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) throw AppException(nameError);
    final emailError = validateEmail(email);
    if (emailError != null) throw AppException(emailError);
    final passwordError = validatePassword(password);
    if (passwordError != null) throw AppException(passwordError);
    if (_find(email) != null) {
      throw const AppException('Já existe uma conta com esse e-mail.');
    }
    final salt = newId();
    final user = {
      'id': newId(),
      'name': name.trim(),
      'email': email.trim().toLowerCase(),
      'salt': salt,
      'hash': _hash(salt, password),
    };
    final users = _users()..add(user);
    await prefs.setString(_usersKey, jsonEncode(users));
    await prefs.setString(_sessionKey, user['id'] as String);
    _changes.add(user['id'] as String);
    return user['id'] as String;
  }

  @override
  Future<void> signOut() async {
    await prefs.remove(_sessionKey);
    _changes.add(null);
  }

  @override
  Future<String?> sendPasswordReset(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) throw AppException(emailError);
    final user = _find(email);
    if (user == null) {
      throw const AppException('Não encontramos uma conta com esse e-mail.');
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    final salt = newId();
    final resets = _resets();
    resets[user['email'] as String] = {
      'salt': salt,
      'hash': _hash(salt, code),
      'exp': DateTime.now().add(const Duration(minutes: 20)).millisecondsSinceEpoch,
    };
    await prefs.setString(_resetsKey, jsonEncode(resets));
    return code;
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final passwordError = validatePassword(newPassword);
    if (passwordError != null) throw AppException(passwordError);
    final users = _users();
    final index = users.indexWhere(
      (item) => item['email'] == email.trim().toLowerCase(),
    );
    if (index < 0) {
      throw const AppException('Não encontramos uma conta com esse e-mail.');
    }
    final user = users[index];
    final reset = _resets()[(user['email'] as String)];
    if (reset is! Map) {
      throw const AppException('Solicite um novo código de recuperação.');
    }
    final data = Map<String, dynamic>.from(reset);
    final expires = data['exp'] as int? ?? 0;
    if (DateTime.now().millisecondsSinceEpoch > expires) {
      throw const AppException('O código expirou. Solicite outro.');
    }
    if (data['hash'] != _hash(data['salt'] as String, code.trim())) {
      throw const AppException('Código de recuperação incorreto.');
    }
    final salt = newId();
    user['salt'] = salt;
    user['hash'] = _hash(salt, newPassword);
    await prefs.setString(_usersKey, jsonEncode(users));
    final resets = _resets()..remove(user['email']);
    await prefs.setString(_resetsKey, jsonEncode(resets));
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final passwordError = validatePassword(newPassword);
    if (passwordError != null) throw AppException(passwordError);
    final users = _users();
    final id = currentUserId;
    final index = users.indexWhere((item) => item['id'] == id);
    if (index < 0) throw const AppException('Sua sessão expirou. Entre novamente.');
    final user = users[index];
    if (user['hash'] != _hash(user['salt'] as String, currentPassword)) {
      throw const AppException('A senha atual está incorreta.');
    }
    final salt = newId();
    user['salt'] = salt;
    user['hash'] = _hash(salt, newPassword);
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  @override
  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final emailError = validateEmail(newEmail);
    if (emailError != null) throw AppException(emailError);
    final users = _users();
    final id = currentUserId;
    final index = users.indexWhere((item) => item['id'] == id);
    if (index < 0) throw const AppException('Sua sessão expirou. Entre novamente.');
    final user = users[index];
    if (user['hash'] != _hash(user['salt'] as String, currentPassword)) {
      throw const AppException('A senha atual está incorreta.');
    }
    final normalized = newEmail.trim().toLowerCase();
    final taken = users.any(
      (item) => item['email'] == normalized && item['id'] != user['id'],
    );
    if (taken) throw const AppException('Já existe uma conta com esse e-mail.');
    user['email'] = normalized;
    await prefs.setString(_usersKey, jsonEncode(users));
  }

  List<Map<String, dynamic>> _users() {
    final raw = prefs.getString(_usersKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic> _resets() {
    final raw = prefs.getString(_resetsKey);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic>? _find(String email) {
    final normalized = email.trim().toLowerCase();
    for (final user in _users()) {
      if (user['email'] == normalized) return user;
    }
    return null;
  }

  Map<String, dynamic>? _current() {
    final id = currentUserId;
    if (id == null) return null;
    for (final user in _users()) {
      if (user['id'] == id) return user;
    }
    return null;
  }

  String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();
}
