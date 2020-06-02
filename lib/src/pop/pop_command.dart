import 'dart:async';
import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/pop_response_parser.dart';

class PopCommand<T> {
  final String _command;
  PopResponseParser parser;
  bool isMultiLine;

  String get command => getCommand();

  final Completer<PopResponse<T>> completer = Completer<PopResponse<T>>();

  PopCommand(this._command,
      {PopResponseParser parser, bool isMultiLine = false}) {
    this.parser = parser;
    this.isMultiLine = isMultiLine;
  }

  String getCommand() {
    return _command;
  }

  String nextCommand(PopResponse response) {
    return null;
  }

  bool isCommandDone(PopResponse response) {
    return true;
  }
}
