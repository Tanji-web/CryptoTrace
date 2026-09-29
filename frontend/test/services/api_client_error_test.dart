import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:frontend/services/api_client.dart';

void main() {
  test('maps rate limiting into a retryable error with retry-after', () {
    final error = ApiException.fromResponse(
      http.Response('{}', 429, headers: {'retry-after': '12'}),
    );

    expect(error.kind, ApiErrorKind.rateLimited);
    expect(error.retryable, isTrue);
    expect(error.retryAfterSeconds, 12);
    expect(error.message, contains('rate-limiting'));
  });

  test('maps missing cases into a non-retryable case error', () {
    final error = ApiException.fromResponse(http.Response('{}', 404));

    expect(error.kind, ApiErrorKind.caseNotFound);
    expect(error.retryable, isFalse);
    expect(error.message, contains('case'));
  });

  test('maps validation failures to a non-retryable error', () {
    final error = ApiException.fromResponse(http.Response('{}', 422));

    expect(error.kind, ApiErrorKind.validation);
    expect(error.retryable, isFalse);
    expect(error.message, contains('valid Ethereum wallet address'));
  });

  test('maps server failures into a retryable error', () {
    final error = ApiException.fromResponse(http.Response('{}', 503));

    expect(error.kind, ApiErrorKind.server);
    expect(error.retryable, isTrue);
    expect(error.message, contains('retry'));
  });
}
