import 'dart:async';
import 'dart:convert';
import 'dart:io';

class HttpClientHelper {
  static Future<SimpleHttpResponse> httpGet(String url,
      {int validStatusCode}) async {
    var client = HttpClient();
    try {
      var request = await client.getUrl(Uri.parse(url));
      var response = await request.close();
      if (validStatusCode != null && response.statusCode != validStatusCode) {
        return SimpleHttpResponse(response.statusCode, null);
      }
      var responseBody = await httpReadResponse(response);
      return SimpleHttpResponse(response.statusCode, responseBody);
    } catch (e) {
      //stderr.writeln('Unable to GET $url: $e');
    }
    return null;
  }

  static Future<String> httpReadResponse(HttpClientResponse response) {
    var completer = Completer<String>();
    var contents = StringBuffer();
    response.transform(utf8.decoder).listen((data) {
      contents.write(data);
    }, onDone: () => completer.complete(contents.toString()));
    return completer.future;
  }
}

class SimpleHttpResponse {
  int statusCode;
  String content;
  SimpleHttpResponse(this.statusCode, this.content);
}
