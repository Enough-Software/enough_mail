import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/pop_response_parser.dart';

class PopStandardParser extends PopResponseParser<String> {
  @override
  PopResponse<String> parse(List<String> responseLines) {
    var response = PopResponse<String>();
    response.result = responseLines.isEmpty ? null : responseLines.first;
    parseOkStatus(responseLines, response);
    return response;
  }
}
