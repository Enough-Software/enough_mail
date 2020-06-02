import 'package:enough_mail/pop/pop_response.dart';
import 'package:enough_mail/src/pop/parsers/pop_list_parser.dart';
import 'package:enough_mail/src/pop/pop_command.dart';

class PopListCommand extends PopCommand<List<MessageListing>> {
  PopListCommand([int messageId])
      : super(messageId == null ? 'LIST' : 'LIST $messageId',
            parser: PopListParser(), isMultiLine: (messageId == null));
}
