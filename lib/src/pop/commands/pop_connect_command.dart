import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/pop/pop_client.dart';
import 'package:enough_mail/src/pop/parsers/pop_connection_parser.dart';
import 'package:enough_mail/src/pop/pop_command.dart';

class PopConnectCommand extends PopCommand<PopServerInfo> {
  PopConnectCommand(PopClient client)
      : super('<wait for initial POP response>',
            parser: PopConnectionParser(client));
}
