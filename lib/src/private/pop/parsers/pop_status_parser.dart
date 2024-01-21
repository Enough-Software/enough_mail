import '../../../pop/pop_response.dart';
import '../pop_response_parser.dart';

/// Parses responses to STATUS command
class PopStatusParser extends PopResponseParser<PopStatus> {
  @override
  PopResponse<PopStatus> parse(List<String> responseLines) {
    final response = PopResponse<PopStatus>();
    parseOkStatus(responseLines, response);
    if (response.isOkStatus) {
      final responseLine = responseLines.first;
      if (responseLine.length > '+OK '.length) {
        final parts = responseLine.substring('+OK '.length).split(' ');
        final numberOfMessages = int.tryParse(parts[0]);
        if (numberOfMessages != null) {
          final totalSizeInBytes = int.tryParse(parts[1]) ?? 0;
          response.result = PopStatus(numberOfMessages, totalSizeInBytes);
        }
      }
    }

    return response;
  }
}
