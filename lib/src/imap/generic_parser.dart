import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

/// Retrieves the response code / prefix of a response, eg 'TRYCREATE' in the response 'NO [TRYCREATE]'.
class GenericParser extends ResponseParser<GenericImapResult> {
  final GenericImapResult _result = GenericImapResult();
  @override
  GenericImapResult parse(
      ImapResponse details, Response<GenericImapResult> response) {
    var text = details.parseText;
    var startIndex = text.indexOf('[');
    if (startIndex != -1 && startIndex < text.length - 2) {
      var endIndex = text.indexOf(']', startIndex + 2);
      if (endIndex != -1) {
        _result.responseCode = text.substring(startIndex + 1, endIndex);
        _result.details = text.substring(endIndex + 1).trim();
      }
    }
    _result.details ??= text;
    return _result;
  }

  @override
  bool parseUntagged(
      ImapResponse details, Response<GenericImapResult> response) {
    var text = details.parseText;
    if (text.startsWith('NO ')) {
      _result.warnings.add(ImapWarning('NO', text.substring('NO '.length)));
    } else if (text.startsWith('BAD ')) {
      _result.warnings.add(ImapWarning('BAD', text.substring('BAD '.length)));
    }
    return super.parseUntagged(details, response);
  }
}
