import '../pop_command.dart';

/// Deletes a specific message
class PopDeleteCommand extends PopCommand<void> {
  /// Creates a new `DELE` request for [messageId]
  PopDeleteCommand(int messageId) : super('DELE $messageId');
}
