import 'package:enough_mail/src/pop/pop_command.dart';

class PopResetCommand extends PopCommand<void> {
  PopResetCommand() : super('RSET');
}
