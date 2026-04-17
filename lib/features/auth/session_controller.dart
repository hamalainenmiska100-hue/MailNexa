import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/mail_tm_api.dart';
import '../../core/models.dart';

class SessionController extends ChangeNotifier {
  SessionController(this._api);

  final MailTmApi _api;

  List<MailDomain> domains = const <MailDomain>[];
  bool loadingDomains = false;
  bool busy = false;
  String? error;

  String? token;
  String? address;
  String? password;
  bool persistSession = true;

  bool get isAuthenticated => token != null && address != null;

  static const String _tokenKey = 'mailnexa_token';
  static const String _addressKey = 'mailnexa_address';
  static const String _passwordKey = 'mailnexa_password';
  static const String _persistKey = 'mailnexa_persist';

  Future<void> loadStoredSession() async {
    final prefs = await SharedPreferences.getInstance();
    persistSession = prefs.getBool(_persistKey) ?? true;
    if (!persistSession) {
      return;
    }

    token = prefs.getString(_tokenKey);
    address = prefs.getString(_addressKey);
    password = prefs.getString(_passwordKey);
    notifyListeners();
  }

  Future<void> fetchDomains() async {
    loadingDomains = true;
    error = null;
    notifyListeners();
    try {
      domains = await _api.fetchDomains();
    } catch (e) {
      error = e.toString();
    } finally {
      loadingDomains = false;
      notifyListeners();
    }
  }

  Future<bool> createAndLogin({required String localPart, required String domain}) async {
    busy = true;
    error = null;
    notifyListeners();

    final normalized = localPart.trim().toLowerCase();
    if (normalized.length < 3 || normalized.length > 30) {
      busy = false;
      error = 'Choose 3 to 30 characters for the mailbox name.';
      notifyListeners();
      return false;
    }
    final email = '$normalized@$domain';
    final generatedPassword = _generatePassword();

    try {
      await _api.createAccount(address: email, password: generatedPassword);
      final auth = await _api.authenticate(address: email, password: generatedPassword);
      token = auth.token;
      address = email;
      password = generatedPassword;
      await _saveSession();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> loginExisting({required String email, required String valuePassword}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final auth = await _api.authenticate(address: email.trim(), password: valuePassword);
      token = auth.token;
      address = email.trim();
      password = valuePassword;
      await _saveSession();
      return true;
    } catch (e) {
      error = e.toString();
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  String generateLocalPart() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return 'mx$now${Random().nextInt(999)}';
  }

  Future<void> setPersistSession(bool enabled) async {
    persistSession = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_persistKey, enabled);
    if (!enabled) {
      await prefs.remove(_tokenKey);
      await prefs.remove(_addressKey);
      await prefs.remove(_passwordKey);
    } else {
      await _saveSession();
    }
  }

  Future<void> logout() async {
    token = null;
    address = null;
    password = null;
    error = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_addressKey);
    await prefs.remove(_passwordKey);
  }

  Future<void> _saveSession() async {
    if (!persistSession || token == null || address == null || password == null) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token!);
    await prefs.setString(_addressKey, address!);
    await prefs.setString(_passwordKey, password!);
    await prefs.setBool(_persistKey, true);
  }

  String _generatePassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#';
    final random = Random.secure();
    return List<String>.generate(18, (int _) => chars[random.nextInt(chars.length)]).join();
  }
}
