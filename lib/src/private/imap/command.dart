import 'dart:async';

import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Contains an IMAP command
class Command {
  /// Creates a new command
  Command(this.commandText,
      {this.logText, this.parts, this.writeTimeout, this.responseTimeout});

  /// Creates a new multiline command
  Command.withContinuation(List<String> parts,
      {String? logText, Duration? writeTimeout, Duration? responseTimeout})
      : this(parts.first,
            parts: parts,
            logText: logText,
            writeTimeout: writeTimeout,
            responseTimeout: responseTimeout);

  /// The command text
  final String commandText;

  /// The optional log text without sensitive data
  final String? logText;

  /// The optional command parts for multiline-requests
  final List<String>? parts;

  /// The current part index of multiline-requests
  int _currentPartIndex = 1;

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
      response.status = ResponseStatus.no;
    } else {
      response.status = ResponseStatus.bad;
    }
    response.result = parser.parse(imapResponse, response);
    return response;
  }

  /// Parses the untagged response
  bool parseUntaggedResponse(ImapResponse details) =>
      parser.parseUntagged(details, response);
}
