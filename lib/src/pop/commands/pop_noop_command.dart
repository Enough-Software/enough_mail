import 'package:enough_mail/src/pop/pop_command.dart';

class PopNoOpCommand extends PopCommand<void> {
  PopNoOpCommand() : super('NOOP');
}
