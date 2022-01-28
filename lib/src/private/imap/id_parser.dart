import '../../imap/id.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses IMAP ID responses
class IdParser extends ResponseParser<Id?> {
  Id? _id;

  @override
  Id? parse(ImapResponse imapResponse, Response response) {
    if (response.isOkStatus) {
      return _id;
    }
    return null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<Id?>? response) {
    final text = imapResponse.parseText;
    if (text.startsWith('ID ')) {
      _id = Id.fromText(text.substring('ID '.length));
      return true;
    } else if (text.startsWith('* ID ')) {
      _id = Id.fromText(text.substring('* ID '.length));
      return true;
    }

    return super.parseUntagged(imapResponse, response);
  }
}
