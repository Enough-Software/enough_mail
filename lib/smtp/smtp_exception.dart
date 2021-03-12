import 'smtp_client.dart';
import 'smtp_response.dart';

class SmtpException implements Exception {
  final SmtpClient smtpClient;
  final SmtpResponse response;
  String? get message => response.message;
  final StackTrace? stackTrace;

  SmtpException(this.smtpClient, this.response, {this.stackTrace});

  @override
  String toString() {
    final buffer = StringBuffer();
    var addNewline = false;
    for (final line in response.responseLines) {
      if (addNewline) {
        buffer.write('\n');
      } else {
        addNewline = true;
      }
      buffer..write(line.code)..write(' ')..write(line.message);
    }
    if (stackTrace != null) {
      buffer..write('\n')..write(stackTrace);
    }
    return buffer.toString();
  }
}
