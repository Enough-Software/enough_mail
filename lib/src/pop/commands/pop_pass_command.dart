import 'package:enough_mail/src/pop/pop_command.dart';

class PopPassCommand extends PopCommand<String> {
  PopPassCommand(String pass) : super('PASS $pass');
}
