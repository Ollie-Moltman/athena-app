import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/scan_result.dart';

class ApiService {
  // TODO: Update to production URL when backend is deployed
  static const String _baseUrl = 'http://localhost:8000';

  /// Submit screen frames for analysis
  Future<String> submitScan({
    required List<Uint8List> frames,
    required int durationMs,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/scan/screen'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'frames': frames.map((f) => base64Encode(f)).toList(),
        'duration_ms': durationMs,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['job_id'] as String;
    } else {
      throw Exception('Failed to submit scan: ${response.statusCode}');
    }
  }

  /// Poll for scan result
  Future<ScanResult?> getResult(String jobId) async {
    final response = await http.get(
      Uri.parse('$_baseUrl/result/$jobId'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['status'] == 'completed') {
        return ScanResult.fromJson(data['result']);
      }
      return null; // still processing
    } else if (response.statusCode == 404) {
      throw Exception('Job not found');
    } else {
      throw Exception('Failed to get result: ${response.statusCode}');
    }
  }

  /// Get scan history
  Future<List<ScanResult>> getHistory() async {
    final response = await http.get(
      Uri.parse('$_baseUrl/history'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => ScanResult.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load history: ${response.statusCode}');
    }
  }
}
