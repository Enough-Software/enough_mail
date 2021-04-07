import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

class LogoutParser extends ResponseParser<String> {
  String? _bye;

  @override
  String? parse(ImapResponse details, Response<String> response) {
    return _bye ?? '';
  }

  @override
  bool parseUntagged(ImapResponse details, Response<String>? response) {
    if (details.parseText.startsWith('BYE')) {
      _bye = details.parseText;
      return true;
    }
    return super.parseUntagged(details, response);
  }
}
