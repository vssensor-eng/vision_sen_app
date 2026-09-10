import 'dart:convert';
import 'package:http/http.dart' as http;

class MobileApiException implements Exception {
  final String message;
  final int? statusCode;
  const MobileApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class MobileApiService {
  final String baseUrl;
  String? token;
  final http.Client _client;
  MobileApiService({required this.baseUrl, this.token, http.Client? client}) : _client = client ?? http.Client();

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), ''));
    final uri = base.replace(path: '${base.path}${path.startsWith('/') ? path : '/$path'}');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers({bool json = false}) {
    final h = <String, String>{'Accept': 'application/json'};
    if (json) h['Content-Type'] = 'application/json; charset=utf-8';
    final t = token;
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
      h['X-OIM-Mobile-Token'] = t;
    }
    return h;
  }

  Map<String, dynamic> _decode(http.Response response) {
    dynamic decoded;
    try { decoded = jsonDecode(utf8.decode(response.bodyBytes)); } catch (_) {
      throw MobileApiException('Sunucudan geçersiz yanıt alındı.', response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String ? decoded['message'] as String : 'Sunucu isteği başarısız (${response.statusCode}).';
      throw MobileApiException(message, response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) throw MobileApiException('Sunucu yanıt formatı geçersiz.', response.statusCode);
    return decoded;
  }

  Future<Map<String, dynamic>> _write(String method, String path, Map<String, dynamic> data) async {
    final uri = _uri(path); final headers = _headers(json: true); final body = jsonEncode(data); late http.Response response;
    if (method == 'POST') response = await _client.post(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
    else if (method == 'PUT') response = await _client.put(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
    else if (method == 'DELETE') response = await _client.delete(uri, headers: headers, body: body).timeout(const Duration(seconds: 20));
    else throw const MobileApiException('Desteklenmeyen mobil API işlemi.');
    return _decode(response);
  }

  Future<Map<String, dynamic>> login({required String login, required String password, bool remember = true}) => _write('POST', '/mobile/login', {'login': login, 'password': password, 'remember': remember});
  Future<Map<String, dynamic>> bundle() async => _decode(await _client.get(_uri('/mobile/bundle'), headers: _headers()).timeout(const Duration(seconds: 20)));
  Future<Map<String, dynamic>> history(int sensorId, {int hours = 24}) async => _decode(await _client.get(_uri('/mobile/history', {'sensor_id': '$sensorId', 'hours': '$hours'}), headers: _headers()).timeout(const Duration(seconds: 20)));
  Future<Map<String, dynamic>> alarms({String state = 'open', int page = 1}) async => _decode(await _client.get(_uri('/mobile/alarms', {'state': state, 'page': '$page'}), headers: _headers()).timeout(const Duration(seconds: 20)));

  Future<Map<String, dynamic>> createDevice({required String name, required String code, required int locationId, required List<String> metrics}) => _write('POST', '/mobile/devices', {'name': name, 'code': code, 'location_id': locationId, 'metrics': metrics});
  Future<Map<String, dynamic>> updateDevice(int id, {required String name, required String code, int? locationId}) => _write('PUT', '/mobile/devices/$id', {'name': name, 'code': code, 'location_id': locationId});
  Future<Map<String, dynamic>> deleteDevice(int id) => _write('DELETE', '/mobile/devices/$id', const {});

  Future<Map<String, dynamic>> createLocation({required String name, required String type, int? parentId, String description = '', String address = ''}) => _write('POST', '/mobile/locations', {'name': name, 'type': type, 'parent_id': parentId, 'description': description, 'address': type == 'building' ? address : null});
  Future<Map<String, dynamic>> updateLocation(int id, {required String name, required String type, int? parentId, String description = '', String address = ''}) => _write('PUT', '/mobile/locations/$id', {'name': name, 'type': type, 'parent_id': parentId, 'description': description, 'address': type == 'building' ? address : null});
  Future<Map<String, dynamic>> deleteLocation(int id) => _write('DELETE', '/mobile/locations/$id', const {});

  Future<Map<String, dynamic>> createSensor({required int deviceId, required String metric, required bool enabled, num? minValue, num? maxValue, int alarmValue = 1}) => _write('POST', '/mobile/sensors', {'device_id': deviceId, 'metric': metric, 'enabled': enabled ? 1 : 0, 'min_value': minValue, 'max_value': maxValue, 'alarm_value': alarmValue});
  Future<Map<String, dynamic>> updateSensor(int id, {required int deviceId, required String metric, required bool enabled, num? minValue, num? maxValue, int alarmValue = 1}) => _write('PUT', '/mobile/sensors/$id', {'device_id': deviceId, 'metric': metric, 'enabled': enabled ? 1 : 0, 'min_value': minValue, 'max_value': maxValue, 'alarm_value': alarmValue});
  Future<Map<String, dynamic>> deleteSensor(int id) => _write('DELETE', '/mobile/sensors/$id', const {});

  Future<void> logout() async { try { await _write('POST', '/mobile/logout', const {}); } catch (_) {} }
  void close() => _client.close();
}
