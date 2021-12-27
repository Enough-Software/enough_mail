import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/pop/parsers/all_parsers.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Retrieves a specific or all messages
class PopRetrieveCommand extends PopCommand<MimeMessage> {
  /// Creates a new RETR commmand
  PopRetrieveCommand(int? messageId)
      : super(
          messageId == null ? 'RETR' : 'RETR $messageId',
          parser: PopRetrieveParser(),
          isMultiLine: messageId == null,
        );
}
