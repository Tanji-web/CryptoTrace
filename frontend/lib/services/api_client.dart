import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/trace_models.dart';

enum ApiErrorKind {
  validation,
  rateLimited,
  caseNotFound,
  network,
  timeout,
  server,
  unknown,
}

class ApiException implements Exception {
  final String message;
  final ApiErrorKind kind;
  final bool retryable;
  final int? retryAfterSeconds;

  const ApiException(
    this.message, {
    this.kind = ApiErrorKind.unknown,
    this.retryable = false,
    this.retryAfterSeconds,
  });

  factory ApiException.fromResponse(http.Response response) {
    switch (response.statusCode) {
      case 422:
        return const ApiException(
          'Please enter a valid Ethereum wallet address.',
          kind: ApiErrorKind.validation,
        );
      case 404:
        return const ApiException(
          'This case could not be found or has expired. Run the trace again to create a new case.',
          kind: ApiErrorKind.caseNotFound,
        );
      case 429:
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        final suffix = retryAfter != null ? ' Try again in about $retryAfter seconds.' : ' Please wait and try again.';
        return ApiException(
          'The backend is temporarily rate-limiting requests.$suffix',
          kind: ApiErrorKind.rateLimited,
          retryable: true,
          retryAfterSeconds: retryAfter,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ApiException(
          'The CryptoTrace backend could not complete the request. Please retry.',
          kind: ApiErrorKind.server,
          retryable: true,
        );
      default:
        return ApiException(
          'The backend returned an unexpected error (HTTP ${response.statusCode}).',
          retryable: response.statusCode >= 500,
        );
    }
  }

  @override
  String toString() => message;
}

class ApiClient {
  // Override for another machine/deployment, for example:
  // flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

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
    } on TimeoutException {
      throw const ApiException(
        'The trace request timed out. The backend may be busy or waiting on an upstream API. Please retry.',
        kind: ApiErrorKind.timeout,
        retryable: true,
      );
    } on http.ClientException {
      throw const ApiException(
        'Could not reach the CryptoTrace backend. Check that it is running and try again.',
        kind: ApiErrorKind.network,
        retryable: true,
      );
    } catch (_) {
      throw const ApiException(
        'Could not reach the CryptoTrace backend. Check that it is running and try again.',
        kind: ApiErrorKind.network,
        retryable: true,
      );
    }

    if (response.statusCode == 200) {
      try {
        return TraceResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } catch (_) {
        throw const ApiException(
          'The backend returned an invalid trace response. Please retry.',
          kind: ApiErrorKind.server,
          retryable: true,
        );
      }
    }

    throw ApiException.fromResponse(response);
  }

  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/health')).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Uri reportUri(String wallet, int maxHops, {String? caseId}) {
    final query = <String, String>{'max_hops': '$maxHops'};
    if (caseId != null && caseId.isNotEmpty) query['case_id'] = caseId;
    return Uri.parse('$baseUrl/api/report/$wallet').replace(queryParameters: query);
  }

  static Uri caseJsonUri(String wallet, int maxHops, {String? caseId}) {
    final query = <String, String>{'max_hops': '$maxHops'};
    if (caseId != null && caseId.isNotEmpty) query['case_id'] = caseId;
    return Uri.parse('$baseUrl/api/case/$wallet').replace(queryParameters: query);
  }
}
