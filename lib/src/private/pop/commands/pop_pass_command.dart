import '../pop_command.dart';

/// Signs in the user using a PASS command
class PopPassCommand extends PopCommand<String> {
  /// Creates a new PASS command
  PopPassCommand(String pass) : super('PASS $pass');

  @override
  String toString() => 'PASS <password scrambled>';
}
