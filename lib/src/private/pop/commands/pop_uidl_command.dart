import '../../../pop/pop_response.dart';
import '../parsers/all_parsers.dart';
import '../pop_command.dart';

/// Lists UIDs of messages or of a specific message
class PopUidListCommand extends PopCommand<List<MessageListing>> {
  /// Creates a new `UIDL` command
  PopUidListCommand([int? messageId])
      : super(
          messageId == null ? 'UIDL' : 'UIDL $messageId',
          parser: PopUidListParser(isMultiLine: messageId == null),
          isMultiLine: messageId == null,
        );
}
