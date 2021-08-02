import 'dart:typed_data';

import 'package:enough_mail/src/imap/metadata.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

class MetaDataParser extends ResponseParser<List<MetaDataEntry>> {
  final List<MetaDataEntry> _entries = <MetaDataEntry>[];

  @override
  List<MetaDataEntry>? parse(
      ImapResponse details, Response<List<MetaDataEntry>> response) {
    //TODO consider supporting [METADATA LONGENTRIES 2199]
    return response.isOkStatus ? _entries : null;
  }

  @override
  bool parseUntagged(
      ImapResponse details, Response<List<MetaDataEntry>>? response) {
    if (details.parseText.startsWith('METADATA ')) {
      // for (var line in details.lines) {
      //   print('-> ${line.rawLine}');
      // }
      var children = details.iterate().values;
      // for (var child in children) {
      //   print('c: ${child.value}');
      //   if (child.children != null) {
      //     for (var cchild in child.children) {
      //       print('cc: ${cchild.value}');
      //     }
      //   }
      // }
      if (children == null ||
          children.length < 4 ||
          children[3].children == null ||
          children[3].children!.length < 2) {
        print('METADATA: unable to parse ${details.parseText}.');
        return super.parseUntagged(details, response);
      }
      var mailboxName = children[2].value;
      var keyValuePairs = children[3].children!;
      for (var i = 0; i < keyValuePairs.length - 1; i += 2) {
        var name = keyValuePairs[i].value!;
        var value = keyValuePairs[i + 1].data ??
            Uint8List.fromList(keyValuePairs[i + 1].value!.codeUnits);
        var metaData =
            MetaDataEntry(mailboxName: mailboxName!, name: name, value: value);
        _entries.add(metaData);
      }
      return true;
    }
    return super.parseUntagged(details, response);
  }
}
