import 'package:enough_mail/pop/pop_client.dart';
import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/pop_response_parser.dart';

/// Parses responses to STATUS command
class PopConnectionParser extends PopResponseParser<PopServerInfo> {
  final PopClient _client;

  PopConnectionParser(this._client);

  @override
  PopResponse<PopServerInfo> parse(List<String> responseLines) {
    var response = PopResponse<PopServerInfo>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      var responseLine = responseLines.first;
      var chunks = responseLine.split(' ');
      response.result = PopServerInfo()..timestamp = chunks.last;
      _client.serverInfo = response.result;
    }
    return response;
  }
}
