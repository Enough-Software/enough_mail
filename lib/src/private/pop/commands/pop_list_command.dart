import '../../../pop/pop_response.dart';
import '../parsers/pop_list_parser.dart';
import '../pop_command.dart';

/// Lists messages or a given specific message
class PopListCommand extends PopCommand<List<MessageListing>> {
  /// Creates a new `LIST` command
  PopListCommand([int? messageId])
      : super(
          messageId == null ? 'LIST' : 'LIST $messageId',
          parser: PopListParser(isMultiLine: messageId == null),
          isMultiLine: messageId == null,
        );
}
