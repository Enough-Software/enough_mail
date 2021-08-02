import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

class NoResponseParser<T> extends ResponseParser<T> {
  final T value;

  NoResponseParser(this.value);

  @override
  T? parse(ImapResponse details, Response<T> response) {
    return response.isOkStatus ? value : null;
  }
}
