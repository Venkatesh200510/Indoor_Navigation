import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/room.dart';
import '../models/route_result.dart';

// ╔══════════════════════════════════════════════════════════════╗
// ║  STEP 1: run ipconfig (Windows) or ifconfig (Mac)           ║
// ║  STEP 2: find your IPv4 address, e.g. 192.168.1.100         ║
// ║  STEP 3: replace the IP below with your actual IP           ║
// ║  STEP 4: make sure phone and computer are on SAME WiFi      ║
// ╚══════════════════════════════════════════════════════════════╝
const String _baseUrl = 'http://10.113.210.25:5000';

const _timeout    = Duration(seconds: 15);
const _maxRetries = 2;

class ApiService {
  // ── Low-level GET with retry ───────────────────────────────
  static Future<Map<String, dynamic>> _get(String endpoint) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final res = await http.get(Uri.parse('$_baseUrl$endpoint')).timeout(_timeout);
        return _parse(res);
      } on TimeoutException {
        if (attempt == _maxRetries) {
  throw ApiException(
          'Connection timed out.\n\n'
          'Checklist:\n'
          '1. Is the backend running?  (npm run dev)\n'
          '2. Did you update the IP in api_service.dart?\n'
          '3. Same WiFi network on phone and computer?\n'
          '4. Windows Firewall blocking port 5000?',
        );
        }
      } on SocketException catch (e) {
        if (attempt == _maxRetries) {
  throw ApiException(
          'Cannot reach server at $_baseUrl\n${e.message}\n\nCheck the IP address.',
        );
        }
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    throw ApiException('Unknown network error.');
  }

  // ── Low-level POST with retry ──────────────────────────────
  static Future<Map<String, dynamic>> _post(String endpoint, Map<String,dynamic> body) async {
    for (int attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        final res = await http.post(
          Uri.parse('$_baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(_timeout);
        return _parse(res);
      } on TimeoutException {
        if (attempt == _maxRetries) throw ApiException('Request timed out. Check server and IP.');
      } on SocketException catch (e) {
        if (attempt == _maxRetries) throw ApiException('Cannot connect: ${e.message}');
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    throw ApiException('Unknown network error.');
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
