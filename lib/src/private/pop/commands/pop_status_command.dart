import '../../../pop/pop_response.dart';
import '../parsers/pop_status_parser.dart';
import '../pop_command.dart';

/// Checks the status of the service, ie the number of messages
class PopStatusCommand extends PopCommand<PopStatus> {
  /// Creates a new STAT command
  PopStatusCommand() : super('STAT', parser: PopStatusParser());
}
