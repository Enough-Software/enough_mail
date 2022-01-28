import '../../imap/response.dart';
import 'imap_response.dart';
import 'parser_helper.dart';

/// Responsible for parsing server responses in form of a single line.
abstract class ResponseParser<T> {
  /// Parses the final response line, either starting with OK, NO or BAD.
  T? parse(ImapResponse imapResponse, Response<T> response);

  /// Parses intermediate untagged response lines.
  bool parseUntagged(ImapResponse imapResponse, Response<T>? response) => false;

  /// Helper method for parsing integer values within a line [details].
  int? parseInt(String details, int startIndex, String endCharacter) =>
      ParserHelper.parseInt(details, startIndex, endCharacter);

  /// Helper method to parse list entries in a line [details].
  List<String>? parseListEntries(
          String details, int startIndex, String? endCharacter,
          [String separator = ' ']) =>
      ParserHelper.parseListEntries(
          details, startIndex, endCharacter, separator);

  /// Helper method to parse a list of integer values in a line [details].
  List<int>? parseListIntEntries(
          String details, int startIndex, String endCharacter,
          [String separator = ' ']) =>
      ParserHelper.parseListIntEntries(
          details, startIndex, endCharacter, separator);
}
