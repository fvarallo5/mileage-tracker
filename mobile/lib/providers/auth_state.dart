import 'package:flutter/foundation.dart';
import '../config/supabase_config.dart';
import '../services/auth_service.dart';

class AuthState extends ChangeNotifier {
  AuthState(this._auth);

  final AuthService _auth;
  bool loading = true;
  String? error;

  bool get isSignedIn => _auth.isSignedIn;
  bool get isAnonymous => _auth.isAnonymous;
  String? get userEmail => _auth.userEmail;
  String? get userId => _auth.currentUser?.id;

  Future<void> init() async {
    if (!SupabaseConfig.isConfigured) {
      loading = false;
      notifyListeners();
      return;
    }

    loading = true;
    notifyListeners();

    try {
      await _auth.restoreSession();
    } catch (_) {}

    _auth.onAuthStateChange.listen((_) => notifyListeners());

    loading = false;
    notifyListeners();
  }

  Future<void> signUp(String email, String password) async {
    error = null;
    notifyListeners();
    try {
      await _auth.signUp(email: email, password: password);
      error = null;
    } on AppAuthException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signIn(String email, String password) async {
    error = null;
    notifyListeners();
    try {
      await _auth.signIn(email: email, password: password);
      error = null;
    } on AppAuthException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> continueAsGuest() async {
    error = null;
    notifyListeners();
    try {
      await _auth.signInAnonymously();
    } on AppAuthException catch (e) {
      error = e.message;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    notifyListeners();
  }
}