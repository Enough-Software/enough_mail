import 'package:enough_mail/src/pop/pop_command.dart';

class PopDeleteCommand extends PopCommand<void> {
  PopDeleteCommand(int messageId) : super('DELE $messageId');
}
