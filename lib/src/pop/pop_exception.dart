import 'pop_client.dart';
import 'pop_response.dart';

/// Informs about an exceptional case when dealing with a POP service
class PopException implements Exception {
  /// Creates a new pop exception
  PopException(this.popClient, this.response, {this.stackTrace})
      : _message = response.toString();

  /// Creates a new POP exception with the given message
  PopException.message(this.popClient, String message)
      : response = PopResponse<String>(isOkStatus: false, result: message),
        stackTrace = null,
        _message = message;

  /// The originating client
  final PopClient popClient;

  /// The response from the POP server
  final PopResponse response;

  final String _message;

  /// The message
  String get message => _message;

  /// The stacktrace, if known
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buffer = StringBuffer()..write('PopException');
    if (response.result != null) {
      buffer
        ..write('\n')
        ..write(response.result);
    }
    if (stackTrace != null) {
      buffer
        ..write('\n')
        ..write(stackTrace);
    }
    return buffer.toString();
  }
}
