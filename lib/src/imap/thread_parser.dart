import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

class ThreadParser extends ResponseParser<SequenceNode> {
  final SequenceNode result;
  ThreadParser({required bool isUidSequence})
      : result = SequenceNode.root(isUidSequence);

  @override
  SequenceNode? parse(ImapResponse details, Response<SequenceNode> response) {
    return response.isOkStatus ? result : null;
  }

  @override
  bool parseUntagged(ImapResponse details, Response<SequenceNode>? response) {
    final text = details.parseText!;
    if (text.startsWith('THREAD ')) {
      final values = details.iterate().values;
      //print(values);
      if (values != null && values.length > 1) {
        final start = values[1].value == 'THREAD' ? 2 : 1;
        for (var i = start; i < values.length; i++) {
          final value = values[i];
          addNode(result, value);
        }
        return true;
      }
    }
    return super.parseUntagged(details, response);
  }

  void addNode(SequenceNode parent, ImapValue value) {
    // print('addNode $value');
    final text = value.value;

    if (text != null) {
      parent = parent.addChild(int.parse(text));
    } else {
      parent = parent.addChild(-1);
    }
    if (value.hasChildren) {
      for (final child in value.children!) {
        addNode(parent, child);
      }
    }
  }
}
