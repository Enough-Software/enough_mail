import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Authenticates the user
class PopUserCommand extends PopCommand<String> {
  /// Creates a new USER command
  PopUserCommand(String user) : super('USER $user');
}
