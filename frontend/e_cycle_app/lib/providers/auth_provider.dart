import 'package:flutter/foundation.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _user;
  String? _token;
  String? _error;
  bool _isLoading = false;

  UserModel? get user => _user;
  String? get token => _token;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null && _token != null;

  Future<bool> login({required String email, required String password}) async {
    _startRequest();

    try {
      final result = await _authService.login(email: email, password: password);

      _token = result.token;
      _user = result.user;
      return true;
    } catch (e) {
      _error = _readableError(e);
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    String phone = '',
  }) async {
    _startRequest();

    try {
      final result = await _authService.register(
        name: name,
        email: email,
        password: password,
        phone: phone,
      );

      _token = result.token;
      _user = result.user;
      return true;
    } catch (e) {
      _error = _readableError(e);
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<bool> updateProfile({
    required String name,
    required String phone,
  }) async {
    if (_token == null) return false;
    _startRequest();

    try {
      final updated = await _authService.updateProfile(
        token: _token!,
        name: name,
        phone: phone,
      );
      _user = updated;
      return true;
    } catch (e) {
      _error = _readableError(e);
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (_token == null) return false;
    _startRequest();

    try {
      await _authService.changePassword(
        token: _token!,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _error = _readableError(e);
      return false;
    } finally {
      _finishRequest();
    }
  }

  Future<UserRewardsData?> getRewards() async {
    if (_token == null) return null;
    try {
      final data = await _authService.getRewards(_token!);
      if (_user != null) {
        _user = UserModel(
          id: _user!.id,
          name: _user!.name,
          email: _user!.email,
          phone: _user!.phone,
          role: _user!.role,
          rewardPoints: data.totalPoints,
        );
        notifyListeners();
      }
      return data;
    } catch (e) {
      _error = _readableError(e);
      notifyListeners();
      return null;
    }
  }

  void _startRequest() {
    _isLoading = true;
    _error = null;
    notifyListeners();
  }

  void _finishRequest() {
    _isLoading = false;
    notifyListeners();
  }

  String _readableError(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  void logout() {
    _user = null;
    _token = null;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
