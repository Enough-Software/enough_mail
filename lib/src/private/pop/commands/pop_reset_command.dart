import '../pop_command.dart';

/// Resets the connection, undeleting any messages previously marked as deleted
class PopResetCommand extends PopCommand<void> {
  /// Creates a new RSET command
  PopResetCommand() : super('RSET');
}
