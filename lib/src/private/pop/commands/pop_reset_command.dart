import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopResetCommand extends PopCommand<void> {
  PopResetCommand() : super('RSET');
}
