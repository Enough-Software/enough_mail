import '../../imap/imap_client.dart';
import '../../imap/response.dart';
import 'imap_response.dart';
import 'response_parser.dart';

/// Parses responses to IMAP ENABLE command
class EnableParser extends ResponseParser<List<Capability>> {
  /// Creates a new parser
  EnableParser(this.info);

  /// Information about the remote service
  final ImapServerInfo info;

  @override
  List<Capability>? parse(
      ImapResponse imapResponse, Response<List<Capability>> response) {
    if (response.isOkStatus) {
      return info.enabledCapabilities;
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<List<Capability>>? response) {
    final line = imapResponse.parseText;
    if (line.startsWith('ENABLED ')) {
      parseCapabilities(line, 'ENABLED '.length);
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }

  /// Parses the capabilities from the given [details]
  void parseCapabilities(String details, int startIndex) {
    final capText = details.substring(startIndex);
    final capNames = capText.split(' ');
    final caps = capNames.map<Capability>((name) => Capability(name));
    info.enabledCapabilities.addAll(caps);
  }
}
