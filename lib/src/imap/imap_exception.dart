import 'imap_client.dart';

class ImapException implements Exception {
  final ImapClient imapClient;
  final String? message;
  final StackTrace? stackTrace;
  final dynamic details;

  ImapException(this.imapClient, this.message, {this.stackTrace, this.details});

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write(message);
    if (details != null) {
      buffer..write('\n')..write(details);
    }
    if (stackTrace != null) {
      buffer..write('\n')..write(stackTrace);
    }
    return buffer.toString();
  }
}
