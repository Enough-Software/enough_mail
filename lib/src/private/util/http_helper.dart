import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'uint8_list_reader.dart';

/// Provides simple HTTP requests
class HttpHelper {
  HttpHelper._();

  /// Gets the specified [url]
  static Future<HttpResult> httpGet(String url,
      {Duration? connectionTimeout}) async {
    try {
      final client = HttpClient();
      if (connectionTimeout != null) {
        client.connectionTimeout = connectionTimeout;
      }
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        return HttpResult(response.statusCode);
      }
      final data = await _readHttpResponse(response);
      return HttpResult(response.statusCode, data);
    } on Exception {
      return HttpResult(400);
    }
  }

  static Future<Uint8List> _readHttpResponse(HttpClientResponse response) {
    final completer = Completer<Uint8List>();
    final contents = OptimizedBytesBuilder();
    response.listen((data) {
      if (data is Uint8List) {
        contents.add(data);
      } else {
        contents.add(Uint8List.fromList(data));
      }
    }, onDone: () => completer.complete(contents.takeBytes()));
    return completer.future;
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
        t = utf8.decode(d);
        _text = t;
      }
    }
    return t;
  }

  /// The response data
  final Uint8List? data;
}
