import '../../../mime_message.dart';
import '../parsers/all_parsers.dart';
import '../pop_command.dart';

/// Retrieves a part of the message
class PopTopCommand extends PopCommand<MimeMessage> {
  /// Creates a new `TOP` command
  PopTopCommand(int messageId, int lines)
      : super(
          'TOP $messageId $lines',
          parser: PopRetrieveParser(),
          isMultiLine: true,
        );
}
