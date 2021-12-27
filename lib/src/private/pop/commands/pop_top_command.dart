import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/pop/parsers/all_parsers.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

/// Retrieves a part of the message
class PopTopCommand extends PopCommand<MimeMessage> {
  /// Creates a new TOP command
  PopTopCommand(int messageId, int lines)
      : super(
          'TOP $messageId $lines',
          parser: PopRetrieveParser(),
          isMultiLine: true,
        );
}
