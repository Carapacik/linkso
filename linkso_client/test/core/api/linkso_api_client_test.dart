import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:linkso_client/src/core/api/api_failure.dart';
import 'package:linkso_client/src/core/api/linkso_api_client.dart';
import 'package:linkso_client/src/core/auth/session_token_store.dart';
import 'package:linkso_client/src/core/config/app_config.dart';

void main() {
  group('LinkSoApiClient', () {
    test('late unauthorized response does not erase a newer login', () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final store = MemorySessionTokenStore();
      await store.write('old-session');
      final client = LinkSoApiClient(
        baseUri: Uri.parse('http://localhost/'),
        usesBearerSession: true,
        sessionTokenStore: store,
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      addTearDown(client.close);
      final Future<void> failure = expectLater(
        client.getJson(path: '/api/v1/auth/session'),
        throwsA(isA<ApiFailure>()),
      );
      await started.future;
      await store.write('new-session');
      response.complete(http.Response('{"error":{"code":"authentication_required","message":"Sign in"}}', 401));
      await failure;
      expect(await store.read(), 'new-session');
    });

    for (final code in [
      'authentication_required',
      'password_incorrect',
      'current_password_invalid',
      'invalid_credentials',
    ]) {
      test('401 $code only clears an invalid account session', () async {
        final store = MemorySessionTokenStore();
        await store.write('existing-session');
        final client = LinkSoApiClient(
          baseUri: Uri.parse('http://localhost/'),
          usesBearerSession: true,
          sessionTokenStore: store,
          client: MockClient((_) async => http.Response('{"error":{"code":"$code","message":"Rejected"}}', 401)),
        );
        addTearDown(client.close);
        await expectLater(client.postJson(path: '/api/v1/action', body: const {}), throwsA(isA<ApiFailure>()));
        expect(await store.read(), code == 'authentication_required' ? isNull : 'existing-session');
      });
    }

    test('returns a decoded JSON object for a successful response', () async {
      final httpClient = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('https://linkso.su/api/v1/links'));
        expect(request.headers['content-type'], 'application/json');
        return http.Response('{"id":"link-id","slug":"abc123"}', 201);
      });
      final client = LinkSoApiClient(baseUri: Uri.parse('https://linkso.su/'), client: httpClient);

      final Map<String, Object?> response = await client.postJson(
        path: '/api/v1/links',
        body: const {'target_url': 'https://example.com'},
      );

      expect(response, {'id': 'link-id', 'slug': 'abc123'});
      client.close();
    });

    test('converts the server error envelope into ApiFailure', () async {
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        client: MockClient(
          (_) async => http.Response(
            '{"error":{"code":"invalid_slug","message":"Invalid slug","field":"slug","request_id":"request-id"}}',
            422,
          ),
        ),
      );

      await expectLater(
        client.postJson(path: '/api/v1/links', body: const {}),
        throwsA(
          isA<ApiFailure>()
              .having((error) => error.statusCode, 'statusCode', 422)
              .having((error) => error.code, 'code', 'invalid_slug')
              .having((error) => error.field, 'field', 'slug')
              .having((error) => error.requestId, 'requestId', 'request-id'),
        ),
      );
      client.close();
    });

    test('adds a stored bearer session only for the native transport', () async {
      final tokenStore = MemorySessionTokenStore();
      await tokenStore.write('native-session');
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        client: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer native-session');
          return http.Response('{"authenticated":true}', 200);
        }),
        sessionTokenStore: tokenStore,
        usesBearerSession: true,
      );

      expect(await client.getJson(path: '/api/v1/auth/session'), {'authenticated': true});
      client.close();
    });

    test('hides malformed server error details behind a stable fallback', () {
      final ApiFailure failure = parseApiFailureResponse(statusCode: 502, responseBody: '<html>proxy error</html>');

      expect(failure.statusCode, 502);
      expect(failure.code, 'unexpected_error');
      expect(failure.message, 'An unexpected server error occurred');
      expect(failure.requestId, isNull);
    });

    testWidgets('aborts a stalled send without retrying or closing the shared client', (tester) async {
      var sends = 0;
      var aborted = false;
      http.BaseRequest? firstRequest;
      final tokenStore = MemorySessionTokenStore();
      await tokenStore.write('native-session');
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        requestTimeout: const Duration(seconds: 1),
        usesBearerSession: true,
        sessionTokenStore: tokenStore,
        client: MockClient.streaming((request, _) async {
          sends++;
          if (sends == 1) {
            firstRequest = request;
            await (request as http.Abortable).abortTrigger;
            aborted = true;
            throw http.RequestAbortedException(request.url);
          }
          return http.StreamedResponse(Stream.value('{}'.codeUnits), 200);
        }),
      );
      addTearDown(client.close);

      final Future<void> failure = expectLater(
        client.postJson(path: '/api/v1/links', body: const {}),
        throwsA(same(requestTimeoutApiFailure)),
      );
      await tester.pump(const Duration(seconds: 1));
      await failure;
      expect(firstRequest, isA<http.Abortable>());
      expect(aborted, isTrue);
      expect(sends, 1);
      expect(await tokenStore.read(), 'native-session');

      expect(await client.getJson(path: '/health/ready'), isEmpty);
      expect(sends, 2);
    });

    testWidgets('times out while receiving an incomplete response body', (tester) async {
      final body = StreamController<List<int>>();
      var aborted = false;
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        requestTimeout: const Duration(seconds: 1),
        client: MockClient.streaming((request, _) async {
          unawaited(
            (request as http.Abortable).abortTrigger!.then((_) {
              aborted = true;
              body.addError(http.RequestAbortedException(request.url));
              unawaited(body.close());
            }),
          );
          body.add('{'.codeUnits);
          return http.StreamedResponse(body.stream, 200);
        }),
      );
      addTearDown(client.close);

      final Future<void> failure = expectLater(
        client.getJson(path: '/api/v1/links'),
        throwsA(same(requestTimeoutApiFailure)),
      );
      await tester.pump(const Duration(seconds: 1));
      await failure;
      expect(aborted, isTrue);
    });

    testWidgets('does not send a late mutation after token storage times out', (tester) async {
      final read = Completer<String?>();
      var sends = 0;
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        requestTimeout: const Duration(seconds: 1),
        usesBearerSession: true,
        sessionTokenStore: _DelayedTokenStore(read.future),
        client: MockClient((_) async {
          sends++;
          return http.Response('{}', 201);
        }),
      );
      addTearDown(client.close);

      final Future<void> failure = expectLater(
        client.postJson(path: '/api/v1/links', body: const {}),
        throwsA(same(requestTimeoutApiFailure)),
      );
      await tester.pump(const Duration(seconds: 1));
      await failure;
      read.complete('late-token');
      await tester.pump();
      expect(sends, 0);
    });

    testWidgets('does not abort a completed request when its deadline passes', (tester) async {
      var aborted = false;
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        requestTimeout: const Duration(seconds: 1),
        client: MockClient.streaming((request, _) async {
          unawaited((request as http.Abortable).abortTrigger!.then((_) => aborted = true));
          return http.StreamedResponse(Stream.value('{}'.codeUnits), 200);
        }),
      );
      addTearDown(client.close);

      expect(await client.getJson(path: '/health/ready'), isEmpty);
      await tester.pump(const Duration(seconds: 2));
      expect(aborted, isFalse);
    });

    test('keeps ordinary connection failures distinct from timeouts', () async {
      final client = LinkSoApiClient(
        baseUri: Uri.parse('https://linkso.su/'),
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(client.close);

      await expectLater(client.getJson(path: '/health/ready'), throwsA(same(networkApiFailure)));
    });
  });

  group('API base URL', () {
    test('normalizes a valid HTTP origin', () {
      expect(createApiBaseUri(value: 'https://linkso.su'), Uri.parse('https://linkso.su/'));
    });

    test('rejects unsupported or ambiguous values', () {
      for (final value in ['ftp://linkso.su', 'https://linkso.su?debug=true', '/relative']) {
        expect(() => createApiBaseUri(value: value), throwsFormatException);
      }
    });
  });
}

final class _DelayedTokenStore(final Future<String?> pendingRead) implements SessionTokenStore {
  @override
  Future<String?> read() => pendingRead;

  @override
  Future<void> write(String token) async {}

  @override
  Future<void> clear() async {}
}
