import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config_app.dart';
import 'mobile_api_service.dart';

class AppSession extends ChangeNotifier {
  static const _tokenKey = 'visionsen_mobile_token';
  final FlutterSecureStorage _storage;
  late MobileApiService api;

  bool initializing = true;
  bool busy = false;
  bool authenticated = false;
  String? error;
  Map<String, dynamic> bundle = const {};

  AppSession({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage() {
    api = MobileApiService(baseUrl: AppConfig.mobileApiBase);
  }

  Map<String, dynamic> get user => Map<String, dynamic>.from(bundle['user'] as Map? ?? const {});
  Map<String, dynamic> get company => Map<String, dynamic>.from(bundle['company'] as Map? ?? const {});
  Map<String, dynamic> get metricCatalog => Map<String, dynamic>.from(bundle['metrics'] as Map? ?? const {});
  List<Map<String, dynamic>> get locations => _mapList(bundle['locations']);
  List<Map<String, dynamic>> get devices => _mapList(bundle['devices']);
  List<Map<String, dynamic>> get sensors => _mapList(bundle['sensors']);
  List<Map<String, dynamic>> get alarms => _mapList(bundle['alarms']);

  bool get canManage => user['manager'] == true || user['role'] == 'manager';

  static List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> restore() async {
    initializing = true;
    notifyListeners();
    final token = await _storage.read(key: _tokenKey);
    if (token == null || token.isEmpty) {
      initializing = false;
      authenticated = false;
      notifyListeners();
      return;
    }
    api.token = token;
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

  Future<bool> login(String login, String password, {bool remember = true}) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final response = await api.login(login: login, password: password, remember: remember);
      final token = response['token'];
      final initialBundle = response['bundle'];
      if (token is! String || token.isEmpty || initialBundle is! Map) {
        throw const MobileApiException('Giriş yanıtı eksik.');
      }
      api.token = token;
      await _storage.write(key: _tokenKey, value: token);
      bundle = Map<String, dynamic>.from(initialBundle);
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

  Future<bool> addDevice({
    required String name,
    required String code,
    required int locationId,
    required List<String> metrics,
  }) async {
    if (!canManage) {
      error = 'Cihaz eklemek için firma yöneticisi yetkisi gerekir.';
      notifyListeners();
      return false;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      await api.createDevice(name: name, code: code, locationId: locationId, metrics: metrics);
      bundle = await api.bundle();
      return true;
    } on MobileApiException catch (e) {
      error = e.message;
      return false;
    } catch (_) {
      error = 'Cihaz eklenemedi. Bağlantıyı kontrol edin.';
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

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
