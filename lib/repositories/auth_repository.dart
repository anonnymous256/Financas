abstract class AuthRepository {
  Stream<String?> authState();

  String? get currentUserId;
  String? get currentEmail;
  String? get currentName;
  bool get sendsResetEmail;

  Future<String> signIn({required String email, required String password});

  Future<String> signUp({
    required String name,
    required String email,
    required String password,
  });

  Future<void> signOut();

  Future<String?> sendPasswordReset(String email);

  Future<void> confirmPasswordReset({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<void> updateEmail({
    required String currentPassword,
    required String newEmail,
  });
}
