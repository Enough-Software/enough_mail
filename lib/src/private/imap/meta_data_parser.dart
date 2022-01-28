import 'dart:typed_data';

import '../../imap/metadata.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses responses to meta data requests
class MetaDataParser extends ResponseParser<List<MetaDataEntry>> {
  final List<MetaDataEntry> _entries = <MetaDataEntry>[];

  //TODO consider supporting [METADATA LONGENTRIES 2199]
  @override
  List<MetaDataEntry>? parse(
          ImapResponse imapResponse, Response<List<MetaDataEntry>> response) =>
      response.isOkStatus ? _entries : null;

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<List<MetaDataEntry>>? response) {
    if (imapResponse.parseText.startsWith('METADATA ')) {
      final children = imapResponse.iterate().values;
      if (children.length < 4 ||
          children[3].children == null ||
          children[3].children!.length < 2) {
        print('METADATA: unable to parse ${imapResponse.parseText}.');
        return super.parseUntagged(imapResponse, response);
      }
      final mailboxName = children[2].value;
      final keyValuePairs = children[3].children!;
      for (var i = 0; i < keyValuePairs.length - 1; i += 2) {
        final name = keyValuePairs[i].value!;
        final value = keyValuePairs[i + 1].data ??
            Uint8List.fromList(keyValuePairs[i + 1].value!.codeUnits);
        final metaData =
            MetaDataEntry(mailboxName: mailboxName!, name: name, value: value);
        _entries.add(metaData);
      }
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }
}
