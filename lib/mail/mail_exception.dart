import 'package:enough_mail/enough_mail.dart';

class MailException implements Exception {
  final MailClient mailClient;
  final String message;
  final StackTrace stackTrace;
  final dynamic details;

  MailException(this.mailClient, this.message, {this.stackTrace, this.details});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer..write('MailException: ')..write(message);
    if (details != null) {
      buffer..write('\n')..write(details);
    }
    if (stackTrace != null) {
      buffer..write('\n')..write(stackTrace);
    }
    return buffer.toString();
  }

  static MailException fromImap(MailClient mailClient, ImapException e) {
    return MailException(mailClient, e.message,
        stackTrace: e.stackTrace, details: e.details);
  }

  static MailException fromPop(MailClient mailClient, PopException e) {
    return MailException(mailClient, e.message,
        stackTrace: e.stackTrace, details: e.response);
  }

  static MailException fromSmtp(MailClient mailClient, SmtpException e) {
    return MailException(mailClient, e.message,
        stackTrace: e.stackTrace, details: e.response);
  }
}
