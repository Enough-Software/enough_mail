import 'pop_client.dart';
import 'pop_response.dart';

class PopException implements Exception {
  final PopClient smtpClient;
  final PopResponse response;
  String get message => response.toString();
  final StackTrace? stackTrace;

  PopException(this.smtpClient, this.response, {this.stackTrace});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('PopException');
    if (response.result != null) {
      buffer..write('\n')..write(response.result);
    }
    if (stackTrace != null) {
      buffer..write('\n')..write(stackTrace);
    }
    return buffer.toString();
  }
}
