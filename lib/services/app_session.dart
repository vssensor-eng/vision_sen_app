import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config_app.dart';
import 'mobile_api_service.dart';

class AppSession extends ChangeNotifier {
  static const _tokenKey = 'visionsen_mobile_token';
  final FlutterSecureStorage _storage;
  late MobileApiService api;
  bool initializing = true, busy = false, authenticated = false;
  String? error;
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
  bool get canManage => user['manager'] == true || user['role'] == 'manager';

  static List<Map<String, dynamic>> _mapList(dynamic raw) => raw is List
      ? raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList()
      : const [];

  Future<void> restore() async {
    initializing = true;
    notifyListeners();
    final saved = await _storage.read(key: _tokenKey);
    if (saved == null || saved.isEmpty) {
      initializing = false;
      authenticated = false;
      notifyListeners();
      return;
    }
    api.token = saved;
    try {
      bundle = await api.bundle();
      authenticated = true;
      error = null;
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      api.token = null;
      authenticated = false;
      bundle = const {};
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
      final response = await api.login(
        login: login,
        password: password,
        remember: remember,
      );
      final t = response['token'];
      final b = response['bundle'];
      if (t is! String || t.isEmpty || b is! Map) {
        throw const MobileApiException('Giriş yanıtı eksik.');
      }
      api.token = t;
      await _storage.write(key: _tokenKey, value: t);
      bundle = Map<String, dynamic>.from(b);
      authenticated = true;
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
    } on MobileApiException catch (e) {
      error = e.message;
      if (e.statusCode == 401) await logout(localOnly: true);
    } catch (_) {
      error = 'Veriler yenilenemedi.';
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
      return true;
    } on MobileApiException catch (e) {
      error = e.message;
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
    await _storage.delete(key: _tokenKey);
    api.token = null;
    authenticated = false;
    bundle = const {};
    error = null;
    notifyListeners();
  }
}
