import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopUserCommand extends PopCommand<String> {
  PopUserCommand(String user) : super('USER $user');
}
