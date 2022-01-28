import '../../pop/pop_response.dart';

/// Parses POP responses
abstract class PopResponseParser<T> {
  /// Parses the OK status of the response
  void parseOkStatus(List<String> responseLines, PopResponse<T> response) {
    response.isOkStatus = responseLines.isNotEmpty &&
        responseLines.first.trim().startsWith('+OK');
  }

  /// Parses the given response lines
  PopResponse<T> parse(List<String> responseLines);
}
