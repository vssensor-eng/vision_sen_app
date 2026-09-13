import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config_app.dart';
import 'mobile_api_service.dart';

class AppSession extends ChangeNotifier {
  static const _tokenKey = 'visionsen_mobile_token';
  static const _bundleCacheKey = 'visionsen_mobile_bundle_cache';
  static const _lastLoginKey = 'visionsen_mobile_last_login';

  final FlutterSecureStorage _storage;
  late MobileApiService api;
  bool initializing = true, busy = false, authenticated = false;
  bool _persistentSession = false;
  String? error;
  String lastLogin = '';
  Map<String, dynamic> bundle = const {};

  AppSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    api = MobileApiService(baseUrl: AppConfig.mobileApiBase);
  }

  Map<String, dynamic> get user =>
      Map<String, dynamic>.from(bundle['user'] as Map? ?? const {});
  Map<String, dynamic> get company =>
      Map<String, dynamic>.from(bundle['company'] as Map? ?? const {});
  Map<String, dynamic> get metricCatalog =>
      Map<String, dynamic>.from(bundle['metrics'] as Map? ?? const {});
  List<Map<String, dynamic>> get locations => _mapList(bundle['locations']);
  List<Map<String, dynamic>> get devices => _mapList(bundle['devices']);
  List<Map<String, dynamic>> get sensors => _mapList(bundle['sensors']);
  List<Map<String, dynamic>> get alarms => _mapList(bundle['alarms']);
  List<String> get timezones {
    final raw = bundle['timezones'];
    if (raw is! List) {
      return const ['UTC', 'Europe/Istanbul'];
    }
    final zones = raw
        .whereType<String>()
        .map((zone) => zone.trim())
        .where((zone) => zone.isNotEmpty)
        .toSet()
        .toList();
    if (!zones.contains('UTC')) zones.insert(0, 'UTC');
    final companyZone = company['timezone']?.toString().trim() ?? '';
    if (companyZone.isNotEmpty && !zones.contains(companyZone)) {
      zones.add(companyZone);
    }
    zones.sort();
    return zones;
  }
  bool get canManage => user['manager'] == true || user['role'] == 'manager';

  static List<Map<String, dynamic>> _mapList(dynamic raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : const [];

  Future<void> _loadBundleCache() async {
    final raw = await _storage.read(key: _bundleCacheKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        bundle = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      await _storage.delete(key: _bundleCacheKey);
    }
  }

  Future<void> _persistBundle() async {
    if (!_persistentSession || bundle.isEmpty) return;
    try {
      await _storage.write(key: _bundleCacheKey, value: jsonEncode(bundle));
    } catch (_) {
      // Cache is an optimization. A storage failure must not invalidate login.
    }
  }

  Future<void> _clearStoredSession() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _bundleCacheKey);
    _persistentSession = false;
  }

  Future<void> restore() async {
    initializing = true;
    error = null;
    notifyListeners();

    lastLogin = (await _storage.read(key: _lastLoginKey) ?? '').trim();
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null || saved.isEmpty) {
      initializing = false;
      authenticated = false;
      bundle = const {};
      notifyListeners();
      return;
    }

    api.token = saved;
    _persistentSession = true;
    await _loadBundleCache();

    try {
      bundle = await api.bundle();
      authenticated = true;
      error = null;
      await _persistBundle();
    } on MobileApiException catch (e) {
      if (e.statusCode == 401) {
        await _clearStoredSession();
        api.token = null;
        authenticated = false;
        bundle = const {};
        error = 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
      } else {
        // 5xx/temporary HTTP errors do not prove that the token is invalid.
        authenticated = true;
        error =
            'Sunucuya geçici olarak ulaşılamıyor. Oturumunuz korunuyor; son veriler gösteriliyor.';
      }
    } catch (_) {
      // DNS, timeout, no-internet or a temporary local-only Wi-Fi route must
      // never destroy a valid stored login token.
      authenticated = true;
      error =
          'İnternet bağlantısı geçici olarak kullanılamıyor. Oturumunuz korunuyor; bağlantı gelince yenileyin.';
    } finally {
      initializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(
    String login,
    String password, {
    bool remember = true,
  }) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final normalizedLogin = login.trim();
      final response = await api.login(
        login: normalizedLogin,
        password: password,
        remember: remember,
      );
      final t = response['token'];
      final b = response['bundle'];
      if (t is! String || t.isEmpty || b is! Map) {
        throw const MobileApiException('Giriş yanıtı eksik.');
      }

      api.token = t;
      bundle = Map<String, dynamic>.from(b);
      authenticated = true;
      lastLogin = normalizedLogin;
      _persistentSession = remember;

      await _storage.write(key: _lastLoginKey, value: normalizedLogin);
      if (remember) {
        await _storage.write(key: _tokenKey, value: t);
        await _persistBundle();
      } else {
        await _storage.delete(key: _tokenKey);
        await _storage.delete(key: _bundleCacheKey);
      }
      return true;
    } on MobileApiException catch (e) {
      error = e.message;
      authenticated = false;
      return false;
    } catch (_) {
      error = 'Sunucuya bağlanılamadı. İnternet bağlantısını kontrol edin.';
      authenticated = false;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (!authenticated || busy) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      bundle = await api.bundle();
      await _persistBundle();
    } on MobileApiException catch (e) {
      error = e.message;
      if (e.statusCode == 401) await logout(localOnly: true);
    } catch (_) {
      error = 'Veriler yenilenemedi. Oturumunuz açık kalmaya devam ediyor.';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> _mutate(
    Future<Map<String, dynamic>> Function() action,
    String fallback,
  ) async {
    if (!canManage) {
      error = 'Bu işlem için firma yöneticisi yetkisi gerekir.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      bundle = await api.bundle();
      await _persistBundle();
      return true;
    } on MobileApiException catch (e) {
      error = e.message;
      if (e.statusCode == 401) await logout(localOnly: true);
      return false;
    } catch (_) {
      error = fallback;
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<bool> addDevice({
    required String name,
    required String code,
    required int locationId,
    required String timezone,
    required int sendIntervalMinutes,
    required List<String> metrics,
  }) =>
      _mutate(
        () => api.createDevice(
          name: name,
          code: code,
          locationId: locationId,
          timezone: timezone,
          sendIntervalMinutes: sendIntervalMinutes,
          metrics: metrics,
        ),
        'Cihaz eklenemedi.',
      );

  Future<bool> updateDevice(
    int id, {
    required String name,
    required String code,
    int? locationId,
    required String timezone,
    required int sendIntervalMinutes,
  }) =>
      _mutate(
        () => api.updateDevice(
          id,
          name: name,
          code: code,
          locationId: locationId,
          timezone: timezone,
          sendIntervalMinutes: sendIntervalMinutes,
        ),
        'Cihaz güncellenemedi.',
      );

  Future<bool> deleteDevice(int id) =>
      _mutate(() => api.deleteDevice(id), 'Cihaz silinemedi.');

  Future<bool> saveLocation({
    int? id,
    required String name,
    required String type,
    int? parentId,
    String description = '',
    String address = '',
    String usageType = '',
    num? areaM2,
  }) =>
      _mutate(
        () => id == null
            ? api.createLocation(
                name: name,
                type: type,
                parentId: parentId,
                description: description,
                address: address,
                usageType: usageType,
                areaM2: areaM2,
              )
            : api.updateLocation(
                id,
                name: name,
                type: type,
                parentId: parentId,
                description: description,
                address: address,
                usageType: usageType,
                areaM2: areaM2,
              ),
        'Konum kaydedilemedi.',
      );

  Future<bool> deleteLocation(int id) =>
      _mutate(() => api.deleteLocation(id), 'Konum silinemedi.');

  Future<bool> saveSensor({
    int? id,
    required int deviceId,
    required String metric,
    required bool enabled,
    num? minValue,
    num? maxValue,
    int alarmValue = 1,
  }) =>
      _mutate(
        () => id == null
            ? api.createSensor(
                deviceId: deviceId,
                metric: metric,
                enabled: enabled,
                minValue: minValue,
                maxValue: maxValue,
                alarmValue: alarmValue,
              )
            : api.updateSensor(
                id,
                deviceId: deviceId,
                metric: metric,
                enabled: enabled,
                minValue: minValue,
                maxValue: maxValue,
                alarmValue: alarmValue,
              ),
        'Sensör kaydedilemedi.',
      );

  Future<bool> deleteSensor(int id) =>
      _mutate(() => api.deleteSensor(id), 'Sensör silinemedi.');

  Future<void> logout({bool localOnly = false}) async {
    if (!localOnly) await api.logout();
    await _clearStoredSession();
    api.token = null;
    authenticated = false;
    bundle = const {};
    error = null;
    notifyListeners();
  }
}
