import 'package:enough_mail/src/imap/id.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

class IdParser extends ResponseParser<Id?> {
  Id? _id;

  @override
  Id? parse(ImapResponse details, Response response) {
    if (response.isOkStatus) {
      return _id;
    }
    return null;
  }

  @override
  bool parseUntagged(ImapResponse details, Response<Id?>? response) {
    final text = details.parseText;
    if (text.startsWith('ID ')) {
      _id = Id.fromText(text.substring('ID '.length));
      return true;
    } else if (text.startsWith('* ID ')) {
      _id = Id.fromText(text.substring('* ID '.length));
      return true;
    }

    return super.parseUntagged(details, response);
  }
}
