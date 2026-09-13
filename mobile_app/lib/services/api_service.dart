import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../models/route_result.dart';

// Web uses the host from the browser URL, so it works on localhost and on
// other devices without rebuilding the app for every network address.
const String _mobileBaseUrl = 'http://10.121.205.25:5000';

List<String> get _baseUrls {
  if (kIsWeb) {
    final browserHost = Uri.base.host;
    final browserUrl = Uri(
      scheme: Uri.base.scheme == 'https' ? 'https' : 'http',
      host: browserHost.isEmpty ? 'localhost' : browserHost,
      port: 5000,
    ).toString().replaceFirst(RegExp(r'/$'), '');
    const localhostUrl = 'http://localhost:5000';
    return browserUrl == localhostUrl
        ? [browserUrl]
        : [browserUrl, localhostUrl];
  }
  return [_mobileBaseUrl, 'http://localhost:5000'];
}

const _timeout    = Duration(seconds: 15);
const _maxRetries = 2;

class ApiService {
  // ── Low-level GET with retry ───────────────────────────────
  static Future<Map<String, dynamic>> _get(String endpoint) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      for (int attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          final res = await http.get(Uri.parse('$baseUrl$endpoint')).timeout(_timeout);
          return _parse(res);
        } on TimeoutException catch (e) {
          lastError = e;
        } on SocketException catch (e) {
          lastError = e;
        }
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    throw ApiException(
      'Unable to reach the backend at ${_baseUrls.join(' or ')}.\n'
      'Make sure the server is running with: npm run dev\n'
      'Last error: $lastError',
    );
  }

  // ── Low-level POST with retry ──────────────────────────────
  static Future<Map<String, dynamic>> _post(String endpoint, Map<String,dynamic> body) async {
    Object? lastError;
    for (final baseUrl in _baseUrls) {
      for (int attempt = 0; attempt <= _maxRetries; attempt++) {
        try {
          final res = await http.post(
            Uri.parse('$baseUrl$endpoint'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          ).timeout(_timeout);
          return _parse(res);
        } on TimeoutException catch (e) {
          lastError = e;
        } on SocketException catch (e) {
          lastError = e;
        }
        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
    }
    throw ApiException(
      'Unable to reach the backend at ${_baseUrls.join(' or ')}.\n'
      'Make sure the server is running with: npm run dev\n'
      'Last error: $lastError',
    );
  }

  static Map<String, dynamic> _parse(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      return jsonDecode(r.body) as Map<String, dynamic>;
    }
    Map<String,dynamic> body;
    try { body = jsonDecode(r.body) as Map<String,dynamic>; }
    catch (_) { throw ApiException('Server error ${r.statusCode}'); }
    throw ApiException(body['message'] as String? ?? 'Error ${r.statusCode}');
  }

  // ── Public API methods ─────────────────────────────────────

  /// Scans a QR code string and returns the matching Room.
  static Future<Room> scanLocation(String qrCode) async {
    final data = await _post('/api/scan-location', {'qr_code': qrCode});
    return Room.fromJson(data['room'] as Map<String,dynamic>);
  }

  /// Returns all rooms for the destination picker.
  static Future<List<Room>> getRooms() async {
    final data = await _get('/api/rooms');
    return (data['rooms'] as List).map((e) => Room.fromJson(e as Map<String,dynamic>)).toList();
  }

  /// Finds the shortest route between two rooms.
  static Future<RouteResult> findRoute(String from, String to) async {
    final data = await _get('/api/find-route?from=$from&to=$to');
    return RouteResult.fromJson(data);
  }

  /// Gets pathway images for a list of room IDs.
  static Future<List<PathwayImage>> getPathwayImages(List<String> nodeIds) async {
    if (nodeIds.isEmpty) return [];
    final data = await _get('/api/get-pathway-images?nodes=${nodeIds.join(',')}');
    return (data['images'] as List)
        .map((e) => PathwayImage.fromJson(e as Map<String,dynamic>))
        .toList();
  }
}

/// Thrown when any API call fails. Contains a user-readable message.
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override String toString() => message;
}
