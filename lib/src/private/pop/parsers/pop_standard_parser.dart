import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/pop_response_parser.dart';

/// Parses generic responses
class PopStandardParser extends PopResponseParser<String> {
  @override
  PopResponse<String> parse(List<String> responseLines) {
    final response = PopResponse<String>()
      ..result = responseLines.isEmpty ? null : responseLines.first;
    parseOkStatus(responseLines, response);
    return response;
  }
}
