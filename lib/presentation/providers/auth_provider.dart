import 'package:flutter/material.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  UserModel? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _user != null;

  void _setLoading(bool value) {
    _isLoading = value;
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
    notifyListeners();
  }
}
