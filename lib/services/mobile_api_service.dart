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

  MobileApiService({required this.baseUrl, this.token, http.Client? client})
      : _client = client ?? http.Client();

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
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      throw MobileApiException('Sunucudan geçersiz yanıt alındı.', response.statusCode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['message'] is String
          ? decoded['message'] as String
          : 'Sunucu isteği başarısız (${response.statusCode}).';
      throw MobileApiException(message, response.statusCode);
    }
    if (decoded is! Map<String, dynamic>) {
      throw MobileApiException('Sunucu yanıt formatı geçersiz.', response.statusCode);
    }
    return decoded;
  }

  Future<Map<String, dynamic>> login({required String login, required String password, bool remember = true}) async {
    final response = await _client.post(
      _uri('/mobile/login'),
      headers: _headers(json: true),
      body: jsonEncode({'login': login, 'password': password, 'remember': remember}),
    ).timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> bundle() async {
    final response = await _client.get(_uri('/mobile/bundle'), headers: _headers()).timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> history(int sensorId, {int hours = 24}) async {
    final response = await _client.get(
      _uri('/mobile/history', {'sensor_id': '$sensorId', 'hours': '$hours'}),
      headers: _headers(),
    ).timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> alarms({String state = 'open', int page = 1}) async {
    final response = await _client.get(
      _uri('/mobile/alarms', {'state': state, 'page': '$page'}),
      headers: _headers(),
    ).timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<Map<String, dynamic>> createDevice({required String name, required String code, required int locationId, required List<String> metrics}) async {
    final response = await _client.post(
      _uri('/mobile/devices'),
      headers: _headers(json: true),
      body: jsonEncode({'name': name, 'code': code, 'location_id': locationId, 'metrics': metrics}),
    ).timeout(const Duration(seconds: 20));
    return _decode(response);
  }

  Future<void> logout() async {
    try {
      await _client.post(_uri('/mobile/logout'), headers: _headers(json: true), body: '{}').timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  void close() => _client.close();
}
