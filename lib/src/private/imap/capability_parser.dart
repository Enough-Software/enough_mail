import '../../imap/imap_client.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses IMAP capability responses
class CapabilityParser extends ResponseParser<List<Capability>> {
  /// Creates a new parser
  CapabilityParser(this.info);

  /// The server information
  final ImapServerInfo info;

  List<Capability>? _capabilities;

  @override
  List<Capability>? parse(
      ImapResponse imapResponse, Response<List<Capability>> response) {
    if (response.isOkStatus) {
      if (imapResponse.parseText.startsWith('OK [CAPABILITY ')) {
        parseCapabilities(
            imapResponse.first.line!, 'OK [CAPABILITY '.length, info);
        _capabilities = info.capabilities;
      }
      return _capabilities ?? [];
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<List<Capability>>? response) {
    final line = imapResponse.parseText;
    if (line.startsWith('OK [CAPABILITY ')) {
      parseCapabilities(line, 'OK [CAPABILITY '.length, info);
      _capabilities = info.capabilities;
      return true;
    } else if (line.startsWith('CAPABILITY ')) {
      parseCapabilities(line, 'CAPABILITY '.length, info);
      _capabilities = info.capabilities;
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }

  /// Parses capabilities from the given text
  static void parseCapabilities(
      String details, int startIndex, ImapServerInfo info) {
    final closeIndex = details.lastIndexOf(']');
    String capText;
    if (closeIndex == -1) {
      capText = details.substring(startIndex);
    } else {
      capText = details.substring(startIndex, closeIndex);
    }
    info.capabilitiesText = capText;
    final capNames = capText.split(' ');
    final caps = capNames.map<Capability>((name) => Capability(name)).toList();
    info.capabilities = caps;
  }
}
