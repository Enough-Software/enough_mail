import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

/// Retrieves the response code / prefix of a response, eg 'TRYCREATE' in the response 'NO [TRYCREATE]'.
class GenericParser extends ResponseParser<GenericImapResult> {
  final GenericImapResult _result = GenericImapResult();
  @override
  GenericImapResult parse(
      ImapResponse details, Response<GenericImapResult> response) {
    final text = details.parseText!;
    final startIndex = text.indexOf('[');
    if (startIndex != -1 && startIndex < text.length - 2) {
      final endIndex = text.indexOf(']', startIndex + 2);
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
      ImapResponse details, Response<GenericImapResult>? response) {
    final text = details.parseText!;
    if (text.startsWith('NO ')) {
      _result.warnings.add(ImapWarning('NO', text.substring('NO '.length)));
      return true;
    } else if (text.startsWith('BAD ')) {
      _result.warnings.add(ImapWarning('BAD', text.substring('BAD '.length)));
      return true;
    } else if (text.startsWith('OK [COPYUID')) {
      final endIndex = text.lastIndexOf(']');
      if (endIndex != -1) {
        _result.responseCode = text.substring('OK ['.length, endIndex);
      }
      return true;
    } else if (text.endsWith('EXPUNGE')) {
      // this is the expunge response for a MOVE operation, ignore
      //print('ignoring expunge: $text');
      return true;
    }
    return super.parseUntagged(details, response);
  }
}
