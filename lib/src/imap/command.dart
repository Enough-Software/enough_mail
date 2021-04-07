import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'dart:async';

import 'imap_response.dart';

class Command {
  String commandText;
  String? logText;
  List<String>? parts;
  int _currentPartIndex = 1;

  Command(this.commandText);

  static Command withContinuation(List<String> parts) {
    var cmd = Command(parts.first);
    cmd.parts = parts;
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
