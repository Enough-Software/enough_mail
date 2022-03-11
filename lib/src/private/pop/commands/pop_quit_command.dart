import '../../../pop/pop_client.dart';
import '../../../pop/pop_response.dart';
import '../pop_command.dart';

/// Signs out and disconnects from the server
class PopQuitCommand extends PopCommand<String> {
  /// Creates a new `QUIT` command
  PopQuitCommand(this._client) : super('QUIT');
  final PopClient _client;

  @override
  String? nextCommand(PopResponse response) {
    _client.disconnect();
    return null;
  }
}
