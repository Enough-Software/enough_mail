import '../../../pop/pop_response.dart';
import '../pop_response_parser.dart';

/// Parses responses to `UIDL` requests
class PopUidListParser extends PopResponseParser<List<MessageListing>> {
  /// Creates a new a UIDL response parser
  PopUidListParser({required this.isMultiLine});

  /// Are multiple or just a single response line expected?
  final bool isMultiLine;

  @override
  PopResponse<List<MessageListing>> parse(List<String> responseLines) {
    final response = PopResponse<List<MessageListing>>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      final result = <MessageListing>[];
      response.result = result;
      for (final line in responseLines) {
        if (line.isEmpty || (isMultiLine && line.startsWith('+OK'))) {
          continue;
        }
        final parts = line.split(' ');
        final MessageListing listing;
        if (parts.length == 2) {
          listing = MessageListing(
            id: int.parse(parts[0]),
            sizeInBytes: 0,
            uid: parts[1],
          );
        } else if (parts.length == 3) {
          // eg '+OK 123 123231'
          listing = MessageListing(
            id: int.parse(parts[1]),
            sizeInBytes: 0,
            uid: parts[2],
          );
        } else {
          throw FormatException('Unexpected UIDL response line [$line]');
        }
        result.add(listing);
      }
    }

    return response;
  }
}
