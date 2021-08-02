import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/pop/parsers/all_parsers.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopTopCommand extends PopCommand<MimeMessage> {
  PopTopCommand(int messageId, int lines)
      : super('TOP $messageId $lines',
            parser: PopRetrieveParser(), isMultiLine: true);
}
