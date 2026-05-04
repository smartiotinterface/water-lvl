// lib/services/auth_service.dart
// v13.1.1 — [FIX CRITICAL] FCM token upload after login/register
// ─────────────────────────────────────────────────────────────────────────────
// [FIX-CRITICAL] login() ও register() এর পরে FCM token RTDB-তে upload হচ্ছিল না।
//   ফলে Cloud Function onStatusChange কখনো push notification পাঠাতে পারতো না।
//   এখন successful auth এর পরে uploadFcmToken() call হয়।

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/secure_storage.dart';
import 'firebase_service.dart';

class AuthService extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _fbService = FirebaseService();
  bool _isLoading = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      // [FIX-CRITICAL] Upload FCM token to RTDB so Cloud Function can send
      // push notifications. Without this, onStatusChange never finds the token.
      await _uploadFcmToken(cred.user?.uid);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'Unexpected error. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _errorMessage = null;
    _setLoading(true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await credential.user?.sendEmailVerification();
      // [FIX-CRITICAL] Upload FCM token on registration too
      await _uploadFcmToken(credential.user?.uid);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = _mapError(e.code);
      _setLoading(false);
      return false;
    } catch (_) {
      _errorMessage = 'Unexpected error. Please try again.';
      _setLoading(false);
      return false;
    }
  }

  // [FIX-CRITICAL] Helper: read token from SecureStorage → upload to RTDB
  Future<void> _uploadFcmToken(String? uid) async {
    if (uid == null) return;
    try {
      final token = await SecureStorage.getFcmToken();
      if (token != null && token.isNotEmpty) {
        await _fbService.uploadFcmToken(uid, token);
        debugPrint('[Auth] FCM token uploaded for uid=$uid');
      }
    } catch (e) {
      // Non-fatal — don't block login on FCM upload failure
      debugPrint('[Auth] FCM token upload failed (non-fatal): $e');
    }
  }

  // [FIX BUG-5] Clear secure storage on logout so FCM token doesn't leak
  Future<void> logout() async {
    await _auth.signOut();
    await SecureStorage.clearAll();
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Validate password strength for registration
  static String? validatePassword(String? v, {bool isLogin = false}) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (isLogin) return null;
    if (v.length < 8) return 'Password must be at least 8 characters';
    if (!v.contains(RegExp(r'[A-Z]'))) return 'Must contain an uppercase letter';
    if (!v.contains(RegExp(r'[0-9]'))) return 'Must contain a number';
    return null;
  }

  String _mapError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'email-already-in-use':
        return 'An account already exists with this email. Please login.';
      case 'weak-password':
        return 'Password is too weak. Use at least 8 characters with numbers.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Check Firebase Console.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return 'Authentication error. Please try again.';
    }
  }
}
