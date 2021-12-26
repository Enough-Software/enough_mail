import 'package:enough_mail/src/mime_message.dart';
import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/pop_response_parser.dart';
import 'package:enough_mail/src/mime_data.dart';

class PopRetrieveParser extends PopResponseParser<MimeMessage> {
  @override
  PopResponse<MimeMessage> parse(List<String?> responseLines) {
    var response = PopResponse<MimeMessage>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      var message = MimeMessage();
      //lines that start with a dot need to remove the dot first:
      var buffer = StringBuffer();
      for (var i = 1; i < responseLines.length; i++) {
        var line = responseLines[i]!;
        if (line.startsWith('.') && line.length > 1) {
          line = line.substring(1);
        }
        buffer
          ..write(line)
          ..write('\r\n');
      }
      message.mimeData = TextMimeData(buffer.toString(), containsHeader: true);
      message.parse();
      response.result = message;
    }
    return response;
  }
}
