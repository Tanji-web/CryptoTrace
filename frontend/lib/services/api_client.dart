import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/trace_models.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiClient {
  // Adjust for your deployment. Kept as a plain constant since this is a
  // single-file prototype frontend.
  static const String baseUrl = 'http://localhost:8000';

  static Future<TraceResult> traceWallet(String walletAddress, int maxHops) async {
    final uri = Uri.parse('$baseUrl/api/trace');
    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'wallet_address': walletAddress, 'max_hops': maxHops}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Could not reach the CryptoTrace backend. Is it running?');
    }

    if (response.statusCode == 200) {
      return TraceResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }

    if (response.statusCode == 422) {
      throw ApiException('Please enter a valid Ethereum wallet address.');
    }

    throw ApiException('The backend returned an unexpected error (HTTP ${response.statusCode}).');
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Uri reportUri(String wallet, int maxHops) {
    return Uri.parse('$baseUrl/api/report/$wallet?max_hops=$maxHops');
  }
}
