import 'smtp_client.dart';
import 'smtp_response.dart';

/// Contains details about SMTP problems
class SmtpException implements Exception {
  /// Creates a new SMTP exception
  SmtpException(this.smtpClient, this.response, {this.stackTrace})
      : _message = response.errorMessage;

  /// Creates a new SMTP exception
  SmtpException.message(this.smtpClient, String message)
      : response = SmtpResponse(['500 $message']),
        stackTrace = null,
        _message = message;

  /// The used SMTP client
  final SmtpClient smtpClient;

  /// The full SMTP response
  final SmtpResponse response;

  final String _message;

  /// The error message
  String? get message => _message;

  /// The stacktrace, if known
  final StackTrace? stackTrace;

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
      buffer
        ..write(line.code)
        ..write(' ')
        ..write(line.message);
    }
    if (stackTrace != null) {
      buffer
        ..write('\n')
        ..write(stackTrace);
    }
    return buffer.toString();
  }
}
