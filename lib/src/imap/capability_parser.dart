import 'package:enough_mail/imap/imap_client.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import 'imap_response.dart';

class CapabilityParser extends ResponseParser<List<Capability>> {
  final ImapServerInfo info;
  CapabilityParser(this.info);

  @override
  List<Capability>? parse(
      ImapResponse details, Response<List<Capability>> response) {
    if (response.isOkStatus) {
      if (details.parseText.startsWith('OK [CAPABILITY ')) {
        parseCapabilities(details.first.line!, 'OK [CAPABILITY '.length);
      }
      return info.capabilities;
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse details, Response<List<Capability>>? response) {
    var line = details.parseText;
    if (line.startsWith('OK [CAPABILITY ')) {
      parseCapabilities(line, 'OK [CAPABILITY '.length);
      return true;
    } else if (line.startsWith('CAPABILITY ')) {
      parseCapabilities(line, 'CAPABILITY '.length);
      return true;
    }
    return super.parseUntagged(details, response);
  }

  void parseCapabilities(String details, int startIndex) {
    var closeIndex = details.lastIndexOf(']');
    var capText;
    if (closeIndex == -1) {
      capText = details.substring(startIndex);
    } else {
      capText = details.substring(startIndex, closeIndex);
    }
    info.capabilitiesText = capText;
    var capNames = capText.split(' ');
    var caps = capNames.map<Capability>((name) => Capability(name)).toList();
    info.capabilities = caps;
  }
}
