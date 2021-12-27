import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Deletes a specific message
class PopDeleteCommand extends PopCommand<void> {
  /// Creates a new delete request for [messageId]
  PopDeleteCommand(int messageId) : super('DELE $messageId');
}
