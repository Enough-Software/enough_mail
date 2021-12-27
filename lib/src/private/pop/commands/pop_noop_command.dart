import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Just tests the connection with a NO OP
class PopNoOpCommand extends PopCommand<void> {
  /// Creates a new NOOP command
  PopNoOpCommand() : super('NOOP');
}
