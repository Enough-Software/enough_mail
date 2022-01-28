import '../../../enough_mail.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses responses to THREAD commands
class ThreadParser extends ResponseParser<SequenceNode> {
  /// Creates a new parser
  ThreadParser({required bool isUidSequence})
      : result = SequenceNode.root(isUid: isUidSequence);

  /// The resulting tree structure
  final SequenceNode result;

  @override
  SequenceNode? parse(
          ImapResponse imapResponse, Response<SequenceNode> response) =>
      response.isOkStatus ? result : null;

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<SequenceNode>? response) {
    final text = imapResponse.parseText;
    if (text.startsWith('THREAD ')) {
      final values = imapResponse.iterate().values;
      //print(values);
      if (values.length > 1) {
        final start = values[1].value == 'THREAD' ? 2 : 1;
        for (var i = start; i < values.length; i++) {
          final value = values[i];
          addNode(result, value);
        }
        return true;
      }
    }
    return super.parseUntagged(imapResponse, response);
  }

  /// Adds the [value] to the [parent]
  void addNode(SequenceNode parent, ImapValue value) {
    // print('addNode $value');
    final text = value.value;
    final SequenceNode added;
    if (text != null) {
      added = parent.addChild(int.parse(text));
    } else {
      added = parent.addChild(-1);
    }
    final children = value.children;
    if (children != null) {
      for (final child in children) {
        addNode(added, child);
      }
    }
  }
}
