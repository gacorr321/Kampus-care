import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;
  AuthStatus _status = AuthStatus.uninitialized;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;
  AuthStatus get status => _status;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Checks if a Firebase user is already signed in (persistent auth).
  /// If so, fetches the user profile from Firestore and sets [AuthStatus.authenticated].
  /// Otherwise sets [AuthStatus.unauthenticated].
  Future<void> checkAuthState() async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        // Fetch user profile from Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(firebaseUser.uid)
            .get();

        if (doc.exists) {
          _user = UserModel.fromMap(doc.data()!);
          _status = AuthStatus.authenticated;
        } else {
          // Firestore doc missing — sign out
          await FirebaseAuth.instance.signOut();
          _status = AuthStatus.unauthenticated;
        }
      } else {
        _status = AuthStatus.unauthenticated;
      }
    } catch (_) {
      // On any error, treat as unauthenticated
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  Future<bool> register({
    required String name,
    required String email,
    required String nim,
    required String phone,
    required String password,
    String? ktmUrl,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      _user = await _repository.register(
        name: name,
        email: email,
        nim: nim,
        phone: phone,
        password: password,
        ktmUrl: ktmUrl,
      );
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> login({
    required String name,
    required String nim,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _errorMessage = null;
      _user = await _repository.login(
        name: name,
        nim: nim,
        password: password,
      );
      _status = AuthStatus.authenticated;
      return true;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('invalid-credential') ||
          errorMsg.contains('wrong-password') ||
          errorMsg.contains('user-not-found')) {
        _errorMessage = 'Nama Lengkap, NIM, atau Password salah';
      } else {
        _errorMessage = errorMsg
            .replaceAll('Exception: ', '')
            .replaceAll(RegExp(r'\[.*\]\s*'), '');
      }
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String nim,
    required String phone,
  }) async {
    if (_user == null) return false;
    try {
      _setLoading(true);
      _errorMessage = null;
      _user = await _repository.updateProfile(
        uid: _user!.uid,
        name: name,
        nim: nim,
        phone: phone,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
