import 'dart:async';
import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/pop_response_parser.dart';

/// Encapsulates a POP command
class PopCommand<T> {
  /// Creates a new POP command
  PopCommand(this._command, {this.parser, this.isMultiLine = false});

  final String _command;

  /// The command specific parser, if any
  PopResponseParser? parser;

  /// Are several response lines expected for this command?
  final bool isMultiLine;

  /// Retrieves the command
  String get command => _command;

  /// The completer for this command
  final Completer<T> completer = Completer<T>();

  /// Retrieves the next command
  ///
  /// Compare [isCommandDone]
  String? nextCommand(PopResponse response) => null;

  /// Checks if there are more steps to this command
  ///
  /// Compare [nextCommand]
  bool isCommandDone(PopResponse response) => true;

  @override
  String toString() => command;
}
