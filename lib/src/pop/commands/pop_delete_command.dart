import 'package:enough_mail/src/pop/pop_command.dart';

class PopDeleteCommand extends PopCommand {
  PopDeleteCommand(int messageId) : super('LIST $messageId');
}
