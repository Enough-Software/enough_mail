import 'dart:async';

import '../../mail_address.dart';
import '../../smtp/smtp_response.dart';

/// Contains a SMTP command
class SmtpCommand {
  /// Creates a new command
  SmtpCommand(this._command);

  final String _command;

  /// Retrieves the command
  String get command => _command;

  /// The completer of this command
  final Completer<SmtpResponse> completer = Completer<SmtpResponse>();

  /// The reply that made a multi-step command fail, if any.
  ///
  /// A command that aborts its exchange, e.g. by sending `RSET` after a
  /// rejected recipient, sets this so that the command fails with the
  /// rejection instead of succeeding with the `250` reply to `RSET`.
  SmtpResponse? failureResponse;

  /// Tries to retrieve the next command data
  SmtpCommandData? next(SmtpResponse response) {
    final text = nextCommand(response);
    if (text != null) {
      return SmtpCommandData(text, null);
    }
    final data = nextCommandData(response);
    if (data != null) {
      return SmtpCommandData(null, data);
    }

    return null;
  }

  /// Tries to retrieve the next command
  String? nextCommand(SmtpResponse response) => null;

  /// Tries to return the next command data
  List<int>? nextCommandData(SmtpResponse response) => null;

  /// Checks if the current command is done
  bool isCommandDone(SmtpResponse response) => true;

  @override
  String toString() => command;
}

/// Ensures that [email] can be embedded into `MAIL FROM:<...>` or
/// `RCPT TO:<...>` without breaking out of the angle brackets.
///
/// Throws an [ArgumentError] when [email] is missing or contains white space,
/// control characters, angle brackets or list separators, compare
/// [MailAddress.isSafeEmail].
String validateEnvelopeAddress(String? email, String description) {
  final error = envelopeAddressError(email, description);
  if (error != null) {
    throw ArgumentError.value(email, description, error);
  }

  return email!;
}

/// Describes why [email] cannot be used as the [description] address of the
/// SMTP envelope, or returns `null` when it can.
String? envelopeAddressError(String? email, String description) {
  if (email == null || email.isEmpty) {
    return 'no $description email address given';
  }
  if (!MailAddress.isSafeEmail(email)) {
    return '$description email address <$email> contains characters that '
        'are not allowed in an SMTP envelope address';
  }

  return null;
}

final _bccHeader = RegExp(
  r'^bcc:.*\r\n(?:[ \t].*\r\n)*',
  multiLine: true,
  caseSensitive: false,
);

/// Removes the `Bcc` header, including its folded continuation lines, from
/// the header section of the rendered [message].
///
/// Only the header section is touched: a body line that happens to start
/// with `Bcc:` is content and stays untouched. The header name is matched
/// case-insensitively, as messages parsed from other sources may use a
/// different capitalisation than the `MessageBuilder` does.
String removeBccHeader(String message) {
  final headerEnd = message.indexOf('\r\n\r\n');
  final headerSection = headerEnd == -1
      ? message
      : message.substring(0, headerEnd + 2);
  final stripped = headerSection.replaceAll(_bccHeader, '');
  if (stripped.length == headerSection.length) {
    return message;
  }

  return headerEnd == -1
      ? stripped
      : stripped + message.substring(headerEnd + 2);
}

/// Prepares [data] for transmission after the `DATA` command.
///
/// Implements the transparency procedure of RFC 5321 section 4.5.2: every
/// line that starts with a period gets one additional period, so that the
/// only `<CRLF>.<CRLF>` the server can see is the end-of-data marker that is
/// appended here. Without it, message content such as two consecutive lines
/// consisting of a single `.` would terminate the DATA phase early and
/// everything after it would be interpreted as SMTP commands.
///
/// The returned text ends with `<CRLF>.` so that the caller's trailing
/// `<CRLF>` completes the end-of-data marker.
String applySmtpTransparency(String data) {
  final buffer = StringBuffer();
  if (data.startsWith('.')) {
    buffer.write('.');
  }
  var start = 0;
  var index = data.indexOf('\n.');
  while (index != -1) {
    buffer
      ..write(data.substring(start, index + 1))
      ..write('.');
    start = index + 1;
    index = data.indexOf('\n.', start);
  }
  buffer.write(data.substring(start));
  if (!data.endsWith('\r\n')) {
    buffer.write('\r\n');
  }
  buffer.write('.');

  return buffer.toString();
}

/// Contains command-specific data
class SmtpCommandData {
  /// Creates a new data
  SmtpCommandData(this.text, this.data);

  /// The textual data
  final String? text;

  /// The binary data
  final List<int>? data;
}
