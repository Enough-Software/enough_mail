import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/pop_response_parser.dart';

/// Parses responses to STATUS command
class PopStatusParser extends PopResponseParser<PopStatus> {
  @override
  PopResponse<PopStatus> parse(List<String?> responseLines) {
    var response = PopResponse<PopStatus>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      var responseLine = responseLines.first!;
      if (responseLine.length > '+OK '.length) {
        var parts = responseLine.substring('+OK '.length).split(' ');
        final numberOfMessages = int.tryParse(parts[0]);
        if (numberOfMessages != null) {
          final totalSizeInBytes = int.tryParse(parts[1]) ?? 0;
          response.result = PopStatus(numberOfMessages, totalSizeInBytes);
        }
      }
    }
    return response;
  }
}
