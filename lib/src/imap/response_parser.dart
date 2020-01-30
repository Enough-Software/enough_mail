import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';

import 'imap_response.dart';

/// Responsible for parsing server responses in form of a single line.
abstract class ResponseParser<T> {
  /// Parses the final response line, either starting with OK, NO or BAD.
  T parse(ImapResponse details, Response<T> response);

  /// Parses intermediate untagged response lines.
  bool parseUntagged(ImapResponse details, Response<T> response) {
    return false;
  }

  /// Helper method for parsing integer values within a line [details].
  int parseInt(String details, int startIndex, String endCharacter) {
    return ParserHelper.parseInt(details, startIndex, endCharacter);
  }

  /// Helper method to parse list entries in a line [details].
  List<String> parseListEntries(
      String details, int startIndex, String endCharacter,
      [String separator = ' ']) {
    return ParserHelper.parseListEntries(details, startIndex, endCharacter);
  }

  /// Helper method to parse a list of integer values in a line [details].
  List<int> parseListIntEntries(
      String details, int startIndex, String endCharacter,
      [String separator = ' ']) {
    return ParserHelper.parseListIntEntries(details, startIndex, endCharacter);
  }
}
