import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'uint8_list_reader.dart';

/// Provides simple HTTP requests
class HttpHelper {
  HttpHelper._();

  /// The maximum accepted size of a response body in bytes.
  ///
  /// Auto-configuration documents are a few kilobytes, everything larger is
  /// most likely not what was asked for.
  static const int maxResponseSize = 1024 * 1024;

  /// Gets the specified [url].
  ///
  /// [timeout] bounds the connection setup, the wait for the response
  /// headers and the download of the body each.
  ///
  /// At most [maxRedirects] redirects are followed. A redirect from `https`
  /// to `http` is never followed, so that an insecure intermediary cannot
  /// downgrade a secure request.
  ///
  /// Returns a result with status code `400` for any error, including
  /// timeouts and responses larger than [maxResponseSize].
  static Future<HttpResult> httpGet(
    String url, {
    Duration? timeout,
    int maxRedirects = 5,
    @Deprecated('Use timeout instead') Duration? connectionTimeout,
  }) async {
    timeout ??= connectionTimeout;
    final client = HttpClient();
    if (timeout != null) {
      client.connectionTimeout = timeout;
    }
    try {
      var uri = Uri.parse(url);
      for (var redirects = 0; ; redirects++) {
        final request = await client.getUrl(uri);
        request.followRedirects = false;
        final response = await _withTimeout(request.close(), timeout);
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null || redirects >= maxRedirects) {
            return HttpResult(response.statusCode);
          }
          final next = uri.resolve(location);
          if (uri.scheme == 'https' && next.scheme != 'https') {
            // never downgrade to an insecure connection
            return HttpResult(response.statusCode);
          }
          uri = next;
          continue;
        }
        if (response.statusCode != 200) {
          await response.drain<void>();

          return HttpResult(response.statusCode);
        }
        final data = await _withTimeout(_readHttpResponse(response), timeout);

        return HttpResult(response.statusCode, data);
      }
    } on Exception {
      return HttpResult(400);
    } finally {
      client.close(force: true);
    }
  }

  static Future<T> _withTimeout<T>(Future<T> future, Duration? timeout) =>
      timeout == null ? future : future.timeout(timeout);

  static Future<Uint8List> _readHttpResponse(
    HttpClientResponse response,
  ) async {
    final contents = OptimizedBytesBuilder();
    await for (final data in response) {
      if (contents.length + data.length > maxResponseSize) {
        throw const HttpException('response exceeds the maximum size');
      }
      contents.add(data is Uint8List ? data : Uint8List.fromList(data));
    }

    return contents.takeBytes();
  }
}

/// The result of a HTTP request
class HttpResult {
  /// Creates a new result
  HttpResult(this.statusCode, [this.data]);

  /// The status code
  final int statusCode;
  String? _text;

  /// The response as text
  String? get text {
    var t = _text;
    if (t == null) {
      final d = data;
      if (d != null) {
        t = utf8.decode(d, allowMalformed: true);
        _text = t;
      }
    }

    return t;
  }

  /// The response data
  final Uint8List? data;
}
