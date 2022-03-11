import '../../../../enough_mail.dart';
import '../parsers/all_parsers.dart';
import '../pop_command.dart';

/// Retrieves a specific or all messages
class PopRetrieveCommand extends PopCommand<MimeMessage> {
  /// Creates a new `RETR` command
  PopRetrieveCommand(int? messageId)
      : super(
          messageId == null ? 'RETR' : 'RETR $messageId',
          parser: PopRetrieveParser(),
          isMultiLine: messageId == null,
        );
}
