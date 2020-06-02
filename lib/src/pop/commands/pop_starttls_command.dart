import 'package:enough_mail/src/pop/pop_command.dart';

/// Compare https://tools.ietf.org/html/rfc2595
class PopStartTlsCommand extends PopCommand<String> {
  PopStartTlsCommand() : super('STLS');
}
