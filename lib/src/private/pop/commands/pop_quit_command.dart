import 'package:enough_mail/src/pop/pop_client.dart';
import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopQuitCommand extends PopCommand<String> {
  final PopClient _client;
  PopQuitCommand(this._client) : super('QUIT');

  @override
  String? nextCommand(PopResponse response) {
    _client.disconnect();
    return null;
  }
}
