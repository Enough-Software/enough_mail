import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

/// Parses search responses
class SearchParser extends ResponseParser<List<int>> {
  List<int> ids = <int>[];
  
  @override
  List<int> parse(ImapResponse details, Response<List<int>> response)  {
    //await Future.delayed(Duration(milliseconds: 200));
    return response.isOkStatus ? ids : null;
  }

  @override
  bool parseUntagged(ImapResponse imapResponse, Response<List<int>> response) {
    var details = imapResponse.parseText;
    if (details.startsWith('SEARCH ')) {
      var listEntries = parseListEntries(details, 'SEARCH '.length, null);
      for (var entry in listEntries) {
        var id = int.parse(entry);
        ids.add(id);
      }
      return true;
    } else {
      return super.parseUntagged(imapResponse, response);
    }
  }

}