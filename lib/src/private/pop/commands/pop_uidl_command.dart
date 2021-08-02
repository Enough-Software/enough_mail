import 'package:enough_mail/src/pop/pop_response.dart';
import 'package:enough_mail/src/private/pop/parsers/all_parsers.dart';
import 'package:enough_mail/src/private/pop/pop_command.dart';

class PopUidListCommand extends PopCommand<List<MessageListing>> {
  PopUidListCommand([int? messageId])
      : super(messageId == null ? 'UIDL' : 'UIDL $messageId',
            parser: PopUidListParser(), isMultiLine: (messageId == null));
}
