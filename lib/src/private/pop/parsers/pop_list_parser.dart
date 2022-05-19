import '../../../pop/pop_response.dart';
import '../pop_response_parser.dart';

/// Parses list responses
class PopListParser extends PopResponseParser<List<MessageListing>> {
  @override
  PopResponse<List<MessageListing>> parse(List<String> responseLines) {
    final response = PopResponse<List<MessageListing>>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      final result = <MessageListing>[];
      response.result = result;
      for (final line in responseLines) {
        if (line.startsWith('+OK')) {
          continue;
        }
        final parts = line.split(' ');
        final MessageListing listing;
        if (parts.length == 2) {
          listing = MessageListing(
              id: int.parse(parts[0]), sizeInBytes: int.parse(parts[1]));
        } else if (parts.length == 3) {
          // eg '+OK 123 123231'
          listing = MessageListing(
              id: int.parse(parts[1]), sizeInBytes: int.parse(parts[2]));
        } else {
          throw FormatException('Unexpected LIST response line [$line]');
        }
        result.add(listing);
      }
    }
    return response;
  }
}
