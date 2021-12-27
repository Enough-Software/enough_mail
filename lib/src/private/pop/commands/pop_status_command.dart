import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/parsers/pop_status_parser.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Checks the status of the service, ie the number of messages
class PopStatusCommand extends PopCommand<PopStatus> {
  /// Creates a new STAT command
  PopStatusCommand() : super('STAT', parser: PopStatusParser());
}
