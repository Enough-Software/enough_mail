import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Starts switching to a secure connection
///
/// Compare https://tools.ietf.org/html/rfc2595
class PopStartTlsCommand extends PopCommand<String> {
  /// Creates a STLS commabd
  PopStartTlsCommand() : super('STLS');
}
