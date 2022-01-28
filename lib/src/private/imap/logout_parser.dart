import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses responses to logout requests
class LogoutParser extends ResponseParser<String> {
  String? _bye;

  @override
  String? parse(ImapResponse imapResponse, Response<String> response) =>
      _bye ?? '';

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<String>? response) {
    if (imapResponse.parseText.startsWith('BYE')) {
      _bye = imapResponse.parseText;
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }
}
