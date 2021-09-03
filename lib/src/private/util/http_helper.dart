import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:enough_mail/src/private/util/uint8_list_reader.dart';

class HttpHelper {
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
    } catch (e) {
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

class HttpResult {
  final int statusCode;
  String? _text;
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

  final Uint8List? data;
  HttpResult(this.statusCode, [this.data]);
}
