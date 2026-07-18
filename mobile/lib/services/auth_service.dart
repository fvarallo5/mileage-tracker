import 'package:supabase_flutter/supabase_flutter.dart';

class AppAuthException implements Exception {
  final String message;
  AppAuthException(this.message);

  @override
  String toString() => message;
}

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  Session? get session => _client.auth.currentSession;

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => session != null;

  bool get isAnonymous => currentUser?.isAnonymous ?? false;

  String? get userEmail => currentUser?.email;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> restoreSession() async {
    await _client.auth.refreshSession();
  }

  Future<void> signUp({required String email, required String password}) async {
    try {
      final user = currentUser;
      if (user != null && user.isAnonymous) {
        await _client.auth.updateUser(
          UserAttributes(email: email.trim(), password: password),
        );
        return;
      }

      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.session == null && response.user != null) {
        throw AppAuthException(
          'Account created. Check your email to confirm, then sign in.',
        );
      }
    } on AppAuthException {
      rethrow;
    } on AuthApiException catch (e) {
      throw AppAuthException(e.message);
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthApiException catch (e) {
      throw AppAuthException(e.message);
    }
  }

  Future<void> signInAnonymously() async {
    try {
      await _client.auth.signInAnonymously();
    } on AuthApiException catch (e) {
      throw AppAuthException(e.message);
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}