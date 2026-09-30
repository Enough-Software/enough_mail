import 'dart:async';

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
