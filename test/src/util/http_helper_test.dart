import 'dart:io';

import 'package:enough_mail/src/private/util/http_helper.dart';
import 'package:test/test.dart';

void main() {
  late HttpServer server;
  late String base;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.address}:${server.port}';
  });

  tearDown(() => server.close(force: true));

  test('follows same-scheme redirects', () async {
    server.listen((request) {
      if (request.uri.path == '/start') {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, '/target')
          ..close();
      } else {
        request.response
          ..write('<ok/>')
          ..close();
      }
    });
    final result = await HttpHelper.httpGet('$base/start');
    expect(result.statusCode, 200);
    expect(result.text, '<ok/>');
  });

  test('stops following redirects after the limit', () async {
    var count = 0;
    server.listen((request) {
      count++;
      request.response
        ..statusCode = HttpStatus.found
        ..headers.set(HttpHeaders.locationHeader, '/loop$count')
        ..close();
    });
    final result = await HttpHelper.httpGet('$base/loop', maxRedirects: 3);
    expect(result.statusCode, HttpStatus.found);
    expect(result.data, isNull);
    expect(count, 4);
  });

  test('rejects responses that exceed the size limit', () async {
    server.listen((request) {
      final chunk = List.filled(64 * 1024, 65);
      for (var i = 0; i < 20; i++) {
        request.response.add(chunk);
      }
      request.response.close();
    });
    final result = await HttpHelper.httpGet('$base/big');
    expect(result.statusCode, 400);
    expect(result.data, isNull);
  });

  test('fails instead of hanging when the server stalls', () async {
    server.listen((request) {
      // never answer
    });
    final result = await HttpHelper.httpGet(
      '$base/stall',
      timeout: const Duration(milliseconds: 300),
    );
    expect(result.statusCode, 400);
  });
}
