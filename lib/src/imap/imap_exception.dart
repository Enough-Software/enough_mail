import 'imap_client.dart';

/// Provides information about an exception
class ImapException implements Exception {
  /// Creates a new exception
  ImapException(this.imapClient, this.message, {this.stackTrace, this.details});

  /// The corresponding IMAP client
  final ImapClient imapClient;

  /// The message if known
  final String? message;

  /// The stacktrace if known
  final StackTrace? stackTrace;

  /// Any exception-specific details if known
  final dynamic details;

  @override
  String toString() {
    final buffer = StringBuffer()..write(message);
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
