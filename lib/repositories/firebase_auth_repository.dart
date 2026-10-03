import 'package:firebase_auth/firebase_auth.dart';

import '../core/utils/app_exception.dart';
import '../core/utils/validators.dart';
import 'auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  bool get sendsResetEmail => true;

  @override
  Stream<String?> authState() => _auth.authStateChanges().map((user) => user?.uid);

  @override
  String? get currentUserId => _auth.currentUser?.uid;

  @override
  String? get currentEmail => _auth.currentUser?.email;

  @override
  String? get currentName => _auth.currentUser?.displayName;

  @override
  Future<String> signIn({required String email, required String password}) async {
    _validateCredentials(email, password);
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      final uid = credential.user?.uid;
      if (uid == null) throw const AppException('Não foi possível entrar. Tente novamente.');
      return uid;
    } on FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error, signingIn: true));
    } catch (error) {
      if (error is AppException) rethrow;
      throw const AppException('Sem conexão com a internet. Tente novamente.');
    }
  }

  @override
  Future<String> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) throw AppException(nameError);
    _validateCredentials(email, password);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      final uid = credential.user?.uid;
      if (uid == null) throw const AppException('Não foi possível criar a conta.');
      return uid;
    } on FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error));
    } catch (error) {
      if (error is AppException) rethrow;
      throw const AppException('Sem conexão com a internet. Tente novamente.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<String?> sendPasswordReset(String email) async {
    final emailError = validateEmail(email);
    if (emailError != null) throw AppException(emailError);
    try {
      await _auth.sendPasswordResetEmail(email: email.trim().toLowerCase());
      return null;
    } on FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error));
    } catch (_) {
      throw const AppException('Sem conexão com a internet. Tente novamente.');
    }
  }

  @override
  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    throw const AppException('Abra o link enviado para o seu e-mail para definir a nova senha.');
  }

  @override
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final passwordError = validatePassword(newPassword);
    if (passwordError != null) throw AppException(passwordError);
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AppException('Sua sessão expirou. Entre novamente.');
    }
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error));
    }
  }

  @override
  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final emailError = validateEmail(newEmail);
    if (emailError != null) throw AppException(emailError);
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw const AppException('Sua sessão expirou. Entre novamente.');
    }
    try {
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      await user.verifyBeforeUpdateEmail(newEmail.trim().toLowerCase());
    } on FirebaseAuthException catch (error) {
      throw AppException(_authMessage(error));
    }
  }

  void _validateCredentials(String email, String password) {
    final emailError = validateEmail(email);
    if (emailError != null) throw AppException(emailError);
    final passwordError = validatePassword(password);
    if (passwordError != null) throw AppException(passwordError);
  }

  String _authMessage(FirebaseAuthException error, {bool signingIn = false}) {
    switch (error.code) {
      case 'invalid-email':
        return 'Informe um e-mail válido.';
      case 'user-not-found':
        return 'Não encontramos uma conta com esse e-mail.';
      case 'wrong-password':
        return 'Senha incorreta.';
      case 'invalid-credential':
        return signingIn
            ? 'E-mail ou senha incorretos.'
            : 'A senha atual está incorreta.';
      case 'email-already-in-use':
        return 'Já existe uma conta com esse e-mail.';
      case 'weak-password':
        return 'A senha precisa ter ao menos 6 caracteres.';
      case 'network-request-failed':
        return 'Sem conexão com a internet. Tente novamente.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde um pouco e tente novamente.';
      case 'user-disabled':
        return 'Esta conta foi desativada.';
      case 'requires-recent-login':
        return 'Por segurança, saia e entre novamente antes de alterar esses dados.';
      default:
        return 'Não foi possível concluir a autenticação. Tente novamente.';
    }
  }
}
