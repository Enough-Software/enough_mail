import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/pop/parsers/all_parsers.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopRetrieveCommand extends PopCommand<MimeMessage> {
  PopRetrieveCommand(int? messageId)
      : super('RETR $messageId',
            parser: PopRetrieveParser(), isMultiLine: true);
}
