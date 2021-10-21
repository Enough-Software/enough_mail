import 'pop_client.dart';
import 'pop_response.dart';

class PopException implements Exception {
  final PopClient popClient;
  final PopResponse response;
  final String _message;
  String get message => _message;
  final StackTrace? stackTrace;

  PopException(this.popClient, this.response, {this.stackTrace})
      : _message = response.toString();

  /// Creates a new SMTP exception
  PopException.message(this.popClient, String message)
      : response = PopResponse<String>(isOkStatus: false, result: message),
        stackTrace = null,
        _message = message;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('PopException');
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
