import 'dart:async';

import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Contains an IMAP command
class Command {
  /// Creates a new command
  Command(
    this.commandText, {
    this.logText,
    this.parts,
    this.rawContinuationData,
    this.writeTimeout,
    this.responseTimeout,
  });

  /// Creates a new multiline command
  Command.withContinuation(
    List<String> parts, {
    String? logText,
    Duration? writeTimeout,
    Duration? responseTimeout,
  }) : this(
         parts.first,
         parts: parts,
         logText: logText,
         writeTimeout: writeTimeout,
         responseTimeout: responseTimeout,
       );

  /// Creates a command whose continuation payload is raw bytes rather than
  /// text.
  ///
  /// Every other continuation command sends text that the socket's default
  /// UTF-8 `IOSink` encoding round-trips exactly (search terms, message
  /// flags: genuine Unicode content). APPEND's literal is not that: it is
  /// already-encoded MIME source (RFC 3501's `CHAR8`), and its `{n}` byte
  /// count is computed over those exact bytes. Routing it through the
  /// `String`-based `writeText` re-encodes any byte outside 7-bit ASCII as
  /// multi-byte UTF-8 on the wire, corrupting the message and, because the
  /// declared `{n}` no longer matches what is sent, desyncing the
  /// connection. This constructor keeps the byte count and the transmitted
  /// bytes identical by carrying the literal as bytes all the way to the
  /// socket's raw `writeData` path.
  Command.withRawContinuation(
    String commandText,
    List<int> rawBytes, {
    String? logText,
    Duration? writeTimeout,
    Duration? responseTimeout,
  }) : this(
         commandText,
         rawContinuationData: rawBytes,
         logText: logText,
         writeTimeout: writeTimeout,
         responseTimeout: responseTimeout,
       );

  /// The command text
  final String commandText;

  /// The optional log text without sensitive data
  final String? logText;

  /// The optional command parts for multiline-requests
  final List<String>? parts;

  /// The optional raw-bytes continuation payload, see
  /// [Command.withRawContinuation].
  final List<int>? rawContinuationData;

  /// The current part index of multiline-requests
  int _currentPartIndex = 1;

  bool _rawContinuationConsumed = false;

  /// The command specific write timeout
  final Duration? writeTimeout;

  /// The command specific response timeout
  final Duration? responseTimeout;

  @override
  String toString() => logText ?? commandText;

  /// Some commands need to be send in chunks
  String? getContinuationResponse(ImapResponse imapResponse) {
    final parts = this.parts;
    if (parts == null || _currentPartIndex >= parts.length) {
      return null;
    }
    final nextPart = parts[_currentPartIndex];
    _currentPartIndex++;

    return nextPart;
  }

  /// The raw-bytes continuation payload, if this command carries one and it
  /// has not already been sent.
  List<int>? getRawContinuationResponse() {
    if (_rawContinuationConsumed) {
      return null;
    }
    final data = rawContinuationData;
    if (data == null) {
      return null;
    }
    _rawContinuationConsumed = true;

    return data;
  }
}

/// Contains an IMAP command task
class CommandTask<T> {
  /// Creates a new task
  CommandTask(this.command, this.id, this.parser);

  /// The command
  final Command command;

  /// The ID to identify the command in responses
  final String id;

  /// The associated response parser
  final ResponseParser<T> parser;

  /// Contains the response
  final Response<T> response = Response<T>();

  /// Completer for this task
  final Completer<T> completer = Completer<T>();
  @override
  String toString() => '$id $command';

  /// Retrieves the IMAP request to send
  String get imapRequest => '$id ${command.commandText}';

  /// Parses the response
  Response<T> parse(ImapResponse imapResponse) {
    if (imapResponse.parseText.startsWith('OK ')) {
      response.status = ResponseStatus.ok;
    } else if (imapResponse.parseText.startsWith('NO ')) {
      response
        ..status = ResponseStatus.no
        ..details = imapResponse.parseText.length > 3
            ? imapResponse.parseText.substring(3)
            : imapResponse.parseText;
    } else {
      response
        ..status = ResponseStatus.bad
        ..details = imapResponse.parseText;
    }
    response.result = parser.parse(imapResponse, response);

    return response;
  }

  /// Parses the untagged response
  bool parseUntaggedResponse(ImapResponse details) =>
      parser.parseUntagged(details, response);
}
