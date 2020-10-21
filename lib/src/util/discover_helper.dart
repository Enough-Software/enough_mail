import 'dart:async';
import 'dart:io';
import 'package:enough_mail/discover/client_config.dart';
import 'package:xml/xml.dart' as xml;
import 'package:basic_utils/basic_utils.dart' as basic;
import 'package:http/http.dart' as http;

/// Lowlevel helper methods for mail scenarios
class DiscoverHelper {
  /// Extracts the domain from the email address (the part after the @)
  static String getDomainFromEmail(String emailAddress) =>
      emailAddress.substring(emailAddress.lastIndexOf('@') + 1);

  /// Extracts the local part from the email address (the part before the @)
  static String getLocalPartFromEmail(String emailAddress) =>
      emailAddress.substring(0, emailAddress.lastIndexOf('@'));

  static String getUserName(ServerConfig config, String email) {
    return (config.usernameType == UsernameType.emailAddress)
        ? email
        : (config.usernameType == UsernameType.unknown)
            ? config.username
            : getLocalPartFromEmail(email);
  }

  static Future<http.Response> httpGet(String url) async {
    try {
      return await http.get(url);
    } catch (e) {
      return http.Response('', 400);
    }
  }

  /// Autodiscovers mail configuration from sub-domain
  ///
  /// compare: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
  static Future<ClientConfig> discoverFromAutoConfigSubdomain(
      String emailAddress,
      [String domain,
      bool isLogEnabled = false]) async {
    domain ??= getDomainFromEmail(emailAddress);
    var url =
        'https://autoconfig.$domain/mail/config-v1.1.xml?emailaddress=$emailAddress';
    if (isLogEnabled) {
      print('Discover: trying $url');
    }
    var response = await httpGet(url);
    if (_isInvalidAutoConfigResponse(response)) {
      url = // try insecure lookup:
          'http://autoconfig.$domain/mail/config-v1.1.xml?emailaddress=$emailAddress';
      if (isLogEnabled) {
        print('Discover: trying $url');
      }
      response = await httpGet(url);
      if (_isInvalidAutoConfigResponse(response)) {
        return null;
      }
    }
    return parseClientConfig(response.body);
  }

  static bool _isInvalidAutoConfigResponse(http.Response response) {
    return (response?.statusCode != 200 ||
        (response?.body == null) ||
        (response.body.isEmpty) ||
        (!response.body.startsWith('<')));
  }

  /// Looks up domain referenced by the email's domain DNS MX record
  static Future<String> discoverMxDomainFromEmail(String emailAddress) async {
    var domain = getDomainFromEmail(emailAddress);
    return discoverMxDomain(domain);
  }

  /// Looks up domain referenced by the domain's DNS MX record
  static Future<String> discoverMxDomain(String domain) async {
    var mxRecords =
        await basic.DnsUtils.lookupRecord(domain, basic.RRecordType.MX);
    if (mxRecords == null || mxRecords.isEmpty) {
      //print('unable to read MX records for [$domain].');
      return null;
    }
    // for (var mxRecord in mxRecords) {
    //   print(
    //       'mx for [$domain]: ${mxRecord.name}=${mxRecord.data}  - rType=${mxRecord.rType}');
    // }
    var mxDomain = mxRecords.first.data;
    var dotIndex = mxDomain.indexOf('.');
    if (dotIndex == -1) {
      return null;
    }
    var lastDotIndex = mxDomain.lastIndexOf('.');
    if (lastDotIndex <= dotIndex - 1) {
      return null;
    }
    mxDomain = mxDomain.substring(dotIndex + 1, lastDotIndex);
    return mxDomain;
  }

  /// Autodiscovers mail configuration from Mozilla ISP DB
  ///
  /// Compare: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
  static Future<ClientConfig> discoverFromIspDb(String domain,
      [bool isLogEnabled = false]) async {
    //print('Querying ISP DB for $domain');
    var url = 'https://autoconfig.thunderbird.net/v1.1/$domain';
    if (isLogEnabled) {
      print('Discover: trying $url');
    }
    var response = await httpGet(url);
    //print('got response ${response.statusCode}');
    if (response.statusCode != 200) {
      return null;
    }
    return parseClientConfig(response.body);
  }

  static Future<ClientConfig> discoverFromVariations(
      List<String> domains, bool isLogEnabled) async {
    final baseDomain = domains.first;
    final variations = _generateDomainBasedVariations(baseDomain);
    for (var i = 1; i < domains.length; i++) {
      _generateDomainBasedVariations(domains[i], variations);
    }
    final futures = <Future<_ConnectionInfo>>[];
    for (final info in variations) {
      futures.add(_tryToConnect(info, isLogEnabled));
    }
    final results = await Future.wait(futures);
    final imapInfo = results.firstWhere((info) => info.ready(ServerType.imap),
        orElse: () => null);
    final popInfo = results.firstWhere((info) => info.ready(ServerType.pop),
        orElse: () => null);
    final smtpInfo = results.firstWhere((info) => info.ready(ServerType.smtp),
        orElse: () => null);
    if ((imapInfo == null && popInfo == null) || (smtpInfo == null)) {
      print(
          'failed to find settings for $baseDomain: imap: ${imapInfo != null ? 'ok' : 'failure'} pop: ${popInfo != null ? 'ok' : 'failure'} smtp: ${smtpInfo != null ? 'ok' : 'failure'} ');
      return null;
    }
    final preferredIncomingInfo = (imapInfo?.isSecure ?? false)
        ? imapInfo
        : (popInfo?.isSecure ?? false)
            ? popInfo
            : imapInfo ?? popInfo;
    if (isLogEnabled) {
      print('');
      print('found mail server for $baseDomain:');
      print(
          'incoming: ${preferredIncomingInfo.host}:${preferredIncomingInfo.port} (${preferredIncomingInfo.serverType})');
      print(
          'outgoing: ${smtpInfo.host}:${smtpInfo.port} (${smtpInfo.serverType})');
    }
    final incoming = ServerConfig(
      hostname: preferredIncomingInfo.host,
      port: preferredIncomingInfo.port,
      type: preferredIncomingInfo.serverType,
      socketType:
          preferredIncomingInfo.isSecure ? SocketType.ssl : SocketType.starttls,
      usernameType: UsernameType.unknown,
      authentication: Authentication.unknown,
    );
    final outgoing = ServerConfig(
      hostname: smtpInfo.host,
      port: smtpInfo.port,
      type: smtpInfo.serverType,
      socketType: smtpInfo.isSecure ? SocketType.ssl : SocketType.starttls,
      usernameType: UsernameType.unknown,
      authentication: Authentication.unknown,
    );
    final config = ClientConfig(version: '1')
      ..emailProviders = [
        ConfigEmailProvider(
          displayName: baseDomain,
          domains: domains,
          displayShortName: baseDomain,
          id: baseDomain,
          incomingServers: [incoming],
          outgoingServers: [outgoing],
        )
          ..preferredIncomingServer = incoming
          ..preferredIncomingImapServer =
              incoming.type == ServerType.imap ? incoming : null
          ..preferredIncomingPopServer =
              incoming.type == ServerType.pop ? incoming : null
          ..preferredOutgoingServer = outgoing
          ..preferredOutgoingSmtpServer = outgoing,
      ];
    return config;
  }

  static Future<_ConnectionInfo> _tryToConnect(
      _ConnectionInfo info, bool isLogEnabled) async {
    try {
      final socket = info.isSecure
          ? await SecureSocket.connect(info.host, info.port,
              timeout: Duration(seconds: 10))
          : await Socket.connect(info.host, info.port,
              timeout: Duration(seconds: 10));
      info.socket = socket;
      if (isLogEnabled) {
        print('success at ${info.host}:${info.port}');
      }
    } catch (e) {
      // ignore connection error
      if (isLogEnabled) {
        print('failed at ${info.host}:${info.port}');
      }
    }
    return info;
  }

  static List<_ConnectionInfo> _generateDomainBasedVariations(String baseDomain,
      [List<_ConnectionInfo> infos]) {
    infos ??= <_ConnectionInfo>[];
    var host = 'imap.$baseDomain';
    addIncomingVariations(host, infos);
    host = 'mail.$baseDomain';
    addIncomingVariations(host, infos);
    host = 'in.$baseDomain';
    addIncomingVariations(host, infos);
    host = 'pop.$baseDomain';
    addIncomingVariations(host, infos);
    host = 'smtp.$baseDomain';
    addOutgoingVariations(host, infos);
    host = 'out.$baseDomain';
    addOutgoingVariations(host, infos);
    return infos;
  }

  static void addIncomingVariations(String host, List<_ConnectionInfo> infos) {
    infos.add(_ConnectionInfo(host, 993, true, ServerType.imap));
    infos.add(_ConnectionInfo(host, 143, false, ServerType.imap));
    infos.add(_ConnectionInfo(host, 995, true, ServerType.pop));
    infos.add(_ConnectionInfo(host, 110, false, ServerType.pop));
  }

  static void addOutgoingVariations(String host, List<_ConnectionInfo> infos) {
    infos.add(_ConnectionInfo(host, 465, true, ServerType.smtp));
    infos.add(_ConnectionInfo(host, 587, false, ServerType.smtp));
    infos.add(_ConnectionInfo(host, 25, false, ServerType.smtp));
  }

  /// Parses a Mozilla-compatible autoconfig file
  ///
  /// Compare: https://wiki.mozilla.org/Thunderbird:Autoconfiguration:ConfigFileFormat
  static ClientConfig parseClientConfig(String definition) {
    //print(definition);
    var config = ClientConfig();
    try {
      // xml.XmlDocument.parse is only available from XML 4.x onwards
      // stable Flutter Test currently requires XML 3.6.1
      // var document = xml.XmlDocument.parse(definition);
      var document = xml.parse(definition);
      for (var node in document.children) {
        if (node is xml.XmlElement && node.name.local == 'clientConfig') {
          var versionAttributes =
              node.attributes.where((a) => a.name?.local == 'version');
          if (versionAttributes.isNotEmpty) {
            config.version = versionAttributes.first.value;
          } else {
            config.version = '1.1';
          }
          var providerNodes = node.children.where(
              (c) => c is xml.XmlElement && c.name.local == 'emailProvider');
          for (var providerNode in providerNodes) {
            if (providerNode is xml.XmlElement) {
              var provider = ConfigEmailProvider();
              provider.id = providerNode.getAttribute('id');
              for (var providerChild in providerNode.children) {
                if (providerChild is xml.XmlElement) {
                  switch (providerChild.name.local) {
                    case 'domain':
                      provider.addDomain(providerChild.text);
                      break;
                    case 'displayName':
                      provider.displayName = providerChild.text;
                      break;
                    case 'displayShortName':
                      provider.displayShortName = providerChild.text;
                      break;
                    case 'incomingServer':
                      provider
                          .addIncomingServer(_parseServerConfig(providerChild));
                      break;
                    case 'outgoingServer':
                      provider
                          .addOutgoingServer(_parseServerConfig(providerChild));
                      break;
                    case 'documentation':
                      provider.documentationUrl ??=
                          providerChild.getAttribute('url');
                      break;
                  }
                }
              }
              config.addEmailProvider(provider);
            }
          }
          break;
        }
      }
    } catch (e) {
      print(e);
      print('unable to parse: \n$definition\n');
    }
    if (config.isNotValid) {
      return null;
    }
    return config;
  }

  static ServerConfig _parseServerConfig(xml.XmlElement serverElement) {
    var server = ServerConfig();
    server.typeName = serverElement.getAttribute('type');
    for (var childNode in serverElement.children) {
      if (childNode is xml.XmlElement) {
        var text = childNode.text;
        switch (childNode.name.local) {
          case 'hostname':
            server.hostname = text;
            break;
          case 'port':
            server.port = int.tryParse(text);
            break;
          case 'socketType':
            server.socketTypeName = text;
            break;
          case 'authentication':
            if (server.authentication != null) {
              server.authenticationAlternativeName = text;
            } else {
              server.authenticationName = text;
            }
            break;
          case 'username':
            server.username = text;
            break;
        }
      }
    }
    return server;
  }
}

class _ConnectionInfo {
  final String host;
  final int port;
  final bool isSecure;
  final ServerType serverType;
  Socket socket;
  _ConnectionInfo(this.host, this.port, this.isSecure, this.serverType);

  bool ready(ServerType type) {
    return serverType == type && socket != null;
  }
}
