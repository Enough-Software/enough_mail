import 'package:enough_mail/src/imap/imap_client.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/response_parser.dart';

import 'imap_response.dart';

class EnableParser extends ResponseParser<List<Capability>> {
  final ImapServerInfo info;
  EnableParser(this.info);

  @override
  List<Capability>? parse(
      ImapResponse details, Response<List<Capability>> response) {
    if (response.isOkStatus) {
      return info.enabledCapabilities;
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse details, Response<List<Capability>>? response) {
    var line = details.parseText;
    if (line.startsWith('ENABLED ')) {
      parseCapabilities(line, 'ENABLED '.length);
      return true;
    }
    return super.parseUntagged(details, response);
  }

  void parseCapabilities(String details, int startIndex) {
    var capText = details.substring(startIndex);
    var capNames = capText.split(' ');
    var caps = capNames.map<Capability>((name) => Capability(name));
    info.enabledCapabilities.addAll(caps);
  }
}
