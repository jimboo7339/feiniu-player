import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:feiniu_player/data/feiniu/api/feiniu_api.dart';
import 'package:feiniu_player/data/feiniu/feiniu_providers.dart';
import 'package:feiniu_player/data/feiniu/models/media_models.dart';

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

class AuthState {
  const AuthState({
    this.initialized = false,
    this.loading = false,
    this.isLoggedIn = false,
    this.host = '',
    this.username = '',
    this.token = '',
    this.serverVersion = '',
    this.error,
    this.accounts = const [],
  });

  final bool initialized;
  final bool loading;
  final bool isLoggedIn;
  final String host;
  final String username;
  final String token;
  final String serverVersion;
  final String? error;
  final List<ServerProfile> accounts;

  AuthState copyWith({
    bool? initialized,
    bool? loading,
    bool? isLoggedIn,
    String? host,
    String? username,
    String? token,
    String? serverVersion,
    String? error,
    List<ServerProfile>? accounts,
    bool clearError = false,
  }) {
    return AuthState(
      initialized: initialized ?? this.initialized,
      loading: loading ?? this.loading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      host: host ?? this.host,
      username: username ?? this.username,
      token: token ?? this.token,
      serverVersion: serverVersion ?? this.serverVersion,
      error: clearError ? null : (error ?? this.error),
      accounts: accounts ?? this.accounts,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  static const _accountsKey = 'accounts';
  static const _activeAccountKey = 'active_account_id';
  static const _secure = FlutterSecureStorage();

  @override
  AuthState build() {
    Future.microtask(_bootstrap);
    return const AuthState();
  }

  FeiniuApi get _api => ref.read(feiniuApiProvider);

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await _loadAccounts(prefs);
    state = state.copyWith(initialized: true, accounts: accounts);

    final activeId = prefs.getString(_activeAccountKey);
    if (activeId == null || activeId.isEmpty) return;

    final account = accounts.where((a) => a.id == activeId).firstOrNull;
    if (account == null) return;

    final pass = await _secure.read(key: 'pass:$activeId');
    final token = await _secure.read(key: 'token:$activeId') ?? '';
    if (token.isNotEmpty) {
      final ok = await _restoreSession(
        host: account.host,
        username: account.username,
        token: token,
      );
      if (ok) return;
    }
    if (pass != null && pass.isNotEmpty) {
      await login(
        host: account.host,
        username: account.username,
        password: pass,
        rememberPassword: true,
      );
    }
  }

  Future<List<ServerProfile>> _loadAccounts(SharedPreferences prefs) async {
    final raw = prefs.getString(_accountsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map<String, dynamic>>()
          .map(ServerProfile.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveAccounts(List<ServerProfile> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(accounts.map((a) => a.toJson()).toList()),
    );
  }

  Future<bool> _restoreSession({
    required String host,
    required String username,
    required String token,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      _api.configure(host: host, token: token);
      final version = await _api.getSysVersion();
      await _api.getUserInfo();
      final ver = version['data'];
      final versionText = ver == null
          ? ''
          : '${ver['version'] ?? ''} / ${ver['mediasrvVersion'] ?? ''}';
      state = state.copyWith(
        loading: false,
        isLoggedIn: true,
        host: host,
        username: username,
        token: token,
        serverVersion: versionText,
      );
      return true;
    } catch (e) {
      state = state.copyWith(loading: false);
      return false;
    }
  }

  Future<bool> login({
    required String host,
    required String username,
    required String password,
    bool rememberPassword = true,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      var normalizedHost = host.trim();
      if (!normalizedHost.startsWith('http://') &&
          !normalizedHost.startsWith('https://')) {
        normalizedHost = 'http://$normalizedHost';
      }
      _api.configure(host: normalizedHost);
      final token = await _api.login(username, password);
      final version = await _api.getSysVersion();
      final userInfo = await _api.getUserInfo();
      final ver = version['data'];
      final versionText = ver == null
          ? ''
          : '${ver['version'] ?? ''} / ${ver['mediasrvVersion'] ?? ''}';

      final accountId = '$normalizedHost|$username';
      final profile = ServerProfile(
        id: accountId,
        host: normalizedHost,
        username: username,
        token: token,
        label: userInfo['data']?['username']?.toString() ?? username,
      );

      final accounts = [...state.accounts.where((a) => a.id != accountId), profile];
      await _saveAccounts(accounts);
      await _secure.write(key: 'token:$accountId', value: token);
      if (rememberPassword) {
        await _secure.write(key: 'pass:$accountId', value: password);
      } else {
        await _secure.delete(key: 'pass:$accountId');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_activeAccountKey, accountId);

      state = state.copyWith(
        loading: false,
        isLoggedIn: true,
        host: normalizedHost,
        username: username,
        token: token,
        serverVersion: versionText,
        accounts: accounts,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        loading: false,
        isLoggedIn: false,
        error: e.toString(),
      );
      return false;
    }
  }

  Future<void> logout() async {
    _api.configure(host: state.host, token: '');
    _api.client.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeAccountKey);
    state = state.copyWith(
      isLoggedIn: false,
      token: '',
      clearError: true,
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
