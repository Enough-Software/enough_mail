import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/pop_response_parser.dart';

/// Parses responses to STATUS command
class PopStatusParser extends PopResponseParser<PopStatus> {
  @override
  PopResponse<PopStatus> parse(List<String> responseLines) {
    var response = PopResponse<PopStatus>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      var responseLine = responseLines.first;
      if (responseLine.length > '+OK '.length) {
        var parts = responseLine.substring('+OK '.length).split(' ');
        var status = PopStatus()..numberOfMessages = int.tryParse(parts[0]);
        if (parts.length > 1) {
          status.totalSizeInBytes = int.tryParse(parts[1]);
        }
        response.result = status;
      }
    }
    return response;
  }
}
