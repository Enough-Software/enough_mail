import '../../enough_mail.dart';

/// Provides details about high level unexpected events
class MailException implements Exception {
  /// Creates a new exception
  MailException(this.mailClient, this.message, {this.stackTrace, this.details});

  /// Creates a new exception from the low level one
  MailException.fromImap(
    MailClient mailClient,
    ImapException e, [
    StackTrace? s,
  ]) : this(
          mailClient,
          '${e.imapClient.logName}:  ${e.message}',
          stackTrace: s ?? e.stackTrace,
          details: e.details,
        );

  /// Creates a new exception from the low level one
  MailException.fromPop(MailClient mailClient, PopException e, [StackTrace? s])
      : this(
          mailClient,
          '${e.popClient.logName}:  ${e.message}',
          stackTrace: s ?? e.stackTrace,
          details: e.response,
        );

  /// Creates a new exception from the low level one
  MailException.fromSmtp(
    MailClient mailClient,
    SmtpException e, [
    StackTrace? s,
  ]) : this(
          mailClient,
          '${e.smtpClient.logName}:  ${e.message}',
          stackTrace: s ?? e.stackTrace,
          details: e.response,
        );

  /// The originating mail client
  final MailClient mailClient;

  /// The error message
  final String? message;

  /// The stacktrace
  final StackTrace? stackTrace;

  /// Any details
  final dynamic details;

  @override
  String toString() {
    final buffer = StringBuffer()
      ..write('MailException: ')
      ..write(message);
    if (details != null) {
      buffer
        ..write('\n')
        ..write(details);
    }
    if (stackTrace != null) {
      buffer
        ..write('\n')
        ..write(stackTrace);
    }

    return buffer.toString();
  }
}
