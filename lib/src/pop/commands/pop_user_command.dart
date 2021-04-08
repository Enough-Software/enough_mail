import 'package:enough_mail/src/pop/pop_command.dart';

class PopUserCommand extends PopCommand<String> {
  PopUserCommand(String user) : super('USER $user');
}
