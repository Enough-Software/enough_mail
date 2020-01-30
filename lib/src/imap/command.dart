import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'dart:async';

import 'imap_response.dart';

class Command {
  String commandText;
  String logText;

  Command(this.commandText);

  @override
  String toString() {
    return logText ?? commandText;
  }
}

class CommandTask<T> {
  final Command command;
  final String id;
  final ResponseParser<T> parser;

  final Response<T> response = Response<T>();
  final Completer<Response<T>> completer = Completer<Response<T>>();

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
    if (parser != null) {
      response.result = parser.parse(imapResponse, response);
    }
    return response;
  }

  bool parseUntaggedResponse(ImapResponse details) {
    if (parser != null) {
      return parser.parseUntagged(details, response);
    } else {
      return false;
    }
  }
}
