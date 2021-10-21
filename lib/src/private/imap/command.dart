import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

import 'dart:async';

import 'imap_response.dart';

class Command {
  final String commandText;
  final String? logText;
  final List<String>? parts;
  int _currentPartIndex = 1;
  final Duration? writeTimeout;
  final Duration? responseTimeout;

  Command(this.commandText,
      {this.logText, this.parts, this.writeTimeout, this.responseTimeout});

  static Command withContinuation(List<String> parts,
      {Duration? writeTimeout, Duration? responseTimeout}) {
    var cmd = Command(parts.first,
        parts: parts,
        writeTimeout: writeTimeout,
        responseTimeout: responseTimeout);
    return cmd;
  }

  @override
  String toString() {
    return logText ?? commandText;
  }

  /// Some commands need to be send in chunks
  String? getContinuationResponse(ImapResponse imapResponse) {
    if (parts == null || _currentPartIndex >= parts!.length) {
      return null;
    }
    var nextPart = parts![_currentPartIndex];
    _currentPartIndex++;
    return nextPart;
  }
}

/// Cotains an IMAP command
class CommandTask<T> {
  final Command command;
  final String id;
  final ResponseParser<T> parser;

  final Response<T> response = Response<T>();
  final Completer<T> completer = Completer<T>();

  CommandTask(this.command, this.id, this.parser);

  @override
  String toString() {
    return id + ' ' + command.toString();
  }

  String toImapRequest() {
    return id + ' ' + command.commandText;
  }

  Response<T> parse(ImapResponse imapResponse) {
    if (imapResponse.parseText.startsWith('OK ')) {
      response.status = ResponseStatus.OK;
    } else if (imapResponse.parseText.startsWith('NO ')) {
      response.status = ResponseStatus.No;
    } else {
      response.status = ResponseStatus.Bad;
    }
    response.result = parser.parse(imapResponse, response);
    return response;
  }

  bool parseUntaggedResponse(ImapResponse details) {
    return parser.parseUntagged(details, response);
  }
}
