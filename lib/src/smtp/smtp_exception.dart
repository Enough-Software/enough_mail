import 'smtp_client.dart';
import 'smtp_response.dart';

/// Contains details about SMTP problems
class SmtpException implements Exception {
  /// The used SMTP client
  final SmtpClient smtpClient;

  /// The full SMTP response
  final SmtpResponse response;

  /// The error message
  String? get message => response.errorMessage;

  /// The stacktrace, if known
  final StackTrace? stackTrace;

  /// Creates a new SMTP exception
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
