import 'dart:async';
import 'dart:io';

import 'package:basic_utils/basic_utils.dart' as basic;
import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_mail/src/discover/client_config.dart';
import 'package:xml/xml.dart' as xml;

import 'http_helper.dart';

/// Lowlevel helper methods for mail scenarios
class DiscoverHelper {
  static const _timeout = Duration(seconds: 20);

  /// Extracts the domain from the email address (the part after the @)
  static String getDomainFromEmail(String emailAddress) =>
      emailAddress.substring(emailAddress.lastIndexOf('@') + 1);

  /// Extracts the local part from the email address (the part before the @)
  static String getLocalPartFromEmail(String emailAddress) =>
      emailAddress.substring(0, emailAddress.lastIndexOf('@'));

  /// Determines the user name from the given [email] address and [config]
  static String getUserName(ServerConfig config, String email) =>
      (config.usernameType == UsernameType.emailAddress)
          ? email
          : (config.usernameType == UsernameType.unknown)
              ? config.username
              : getLocalPartFromEmail(email);

  /// Autodiscovers mail configuration from sub-domain
  ///
  /// compare: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
  static Future<ClientConfig?> discoverFromAutoConfigSubdomain(
    String emailAddress, {
    String? domain,
    bool isLogEnabled = false,
  }) async {
    domain ??= getDomainFromEmail(emailAddress);
    var url =
        'https://autoconfig.$domain/mail/config-v1.1.xml?emailaddress=$emailAddress';
    if (isLogEnabled) {
      print('Discover: trying $url');
    }
    var response = await HttpHelper.httpGet(url, connectionTimeout: _timeout);
    if (_isInvalidAutoConfigResponse(response)) {
      url = // try insecure lookup:
          'http://autoconfig.$domain/mail/config-v1.1.xml?emailaddress=$emailAddress';
      if (isLogEnabled) {
        print('Discover: trying $url');
      }
      response = await HttpHelper.httpGet(url, connectionTimeout: _timeout);
      if (_isInvalidAutoConfigResponse(response)) {
        return null;
      }
    }
    return parseClientConfig(response.text!);
  }

  static bool _isInvalidAutoConfigResponse(HttpResult response) =>
      response.statusCode != 200 ||
      (response.text == null) ||
      (response.text!.isEmpty) ||
      (!response.text!.startsWith('<'));

  /// Looks up domain referenced by the email's domain DNS MX record
  static Future<String?> discoverMxDomainFromEmail(String emailAddress) async {
    final domain = getDomainFromEmail(emailAddress);
    return discoverMxDomain(domain);
  }

  /// Looks up domain referenced by the domain's DNS MX record
  static Future<String?> discoverMxDomain(String domain) async {
    final mxRecords =
        await basic.DnsUtils.lookupRecord(domain, basic.RRecordType.MX);
    if (mxRecords == null || mxRecords.isEmpty) {
      //print('unable to read MX records for [$domain].');
      return null;
    }
    // for (var mxRecord in mxRecords) {
    //   print(
    //       'mx for [$domain]: ${mxRecord.name}=${mxRecord.data}  '
    //       '- rType=${mxRecord.rType}');
    // }
    var mxDomain = mxRecords.first.data;
    final dotIndex = mxDomain.indexOf('.');
    if (dotIndex == -1) {
      return null;
    }
    final lastDotIndex = mxDomain.lastIndexOf('.');
    if (lastDotIndex <= dotIndex - 1) {
      return null;
    }
    mxDomain = mxDomain.substring(dotIndex + 1, lastDotIndex);
    return mxDomain;
  }

  /// Autodiscovers mail configuration from Mozilla ISP DB
  ///
  /// Compare: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
  static Future<ClientConfig?> discoverFromIspDb(String? domain,
      {bool isLogEnabled = false}) async {
    //print('Querying ISP DB for $domain');
    final url = 'https://autoconfig.thunderbird.net/v1.1/$domain';
    if (isLogEnabled) {
      print('Discover: trying $url');
    }
    final response = await HttpHelper.httpGet(url, connectionTimeout: _timeout);
    //print('got response ${response.statusCode}');
    if (response.statusCode != 200) {
      return null;
    }
    return parseClientConfig(response.text!);
  }

  /// Discovers settings from the list of [domains]
  static Future<ClientConfig?> discoverFromCommonDomains(
    List<String> domains, {
    bool isLogEnabled = false,
  }) async {
    assert(domains.isNotEmpty, 'At least 1 input domain is required');
    final baseDomain = domains.first;
    final variations = _generateDomainBasedVariations(baseDomain);
    for (var i = 1; i < domains.length; i++) {
      _generateDomainBasedVariations(domains[i], variations);
    }
    return discoverFromConnections(baseDomain, variations,
        isLogEnabled: isLogEnabled);
  }

  /// Discovers the settings from the given [baseDomain]
  static Future<ClientConfig?> discoverFromConnections(
    String baseDomain,
    List<DiscoverConnectionInfo> connectionInfos, {
    bool isLogEnabled = false,
  }) async {
    final futures = <Future<DiscoverConnectionInfo>>[];
    for (final info in connectionInfos) {
      futures.add(_tryToConnect(info, isLogEnabled));
    }
    final results = await Future.wait(futures);
    final imapInfo =
        results.firstWhereOrNull((info) => info.ready(ServerType.imap));
    final popInfo =
        results.firstWhereOrNull((info) => info.ready(ServerType.pop));
    final smtpInfo =
        results.firstWhereOrNull((info) => info.ready(ServerType.smtp));
    if ((imapInfo == null && popInfo == null) || (smtpInfo == null)) {
      print('failed to find settings for $baseDomain: '
          'imap: ${imapInfo != null ? 'ok' : 'failure'} '
          'pop: ${popInfo != null ? 'ok' : 'failure'} '
          'smtp: ${smtpInfo != null ? 'ok' : 'failure'} ');
      return null;
    }
    final preferredIncomingInfo = (imapInfo?.isSecure ?? false)
        ? imapInfo!
        : (popInfo?.isSecure ?? false)
            ? popInfo!
            : imapInfo ?? popInfo!;
    if (isLogEnabled) {
      print('');
      print('found mail server for $baseDomain:');
      print('incoming: ${preferredIncomingInfo.host}:'
          '${preferredIncomingInfo.port} '
          '(${preferredIncomingInfo.serverType})');
      print('outgoing: ${smtpInfo.host}:${smtpInfo.port} '
          '(${smtpInfo.serverType})');
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
          domains: [baseDomain],
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

  static Future<DiscoverConnectionInfo> _tryToConnect(
      DiscoverConnectionInfo info, bool isLogEnabled) async {
    try {
      // ignore: close_sinks
      final socket = info.isSecure
          ? await SecureSocket.connect(info.host, info.port,
              timeout: const Duration(seconds: 10))
          : await Socket.connect(info.host, info.port,
              timeout: const Duration(seconds: 10));
      info.socket = socket;
      if (isLogEnabled) {
        print('success at ${info.host}:${info.port}');
      }
    } on Exception {
      // ignore connection error
      if (isLogEnabled) {
        print('failed at ${info.host}:${info.port}');
      }
    }
    return info;
  }

  static List<DiscoverConnectionInfo> _generateDomainBasedVariations(
      String? baseDomain,
      [List<DiscoverConnectionInfo>? infos]) {
    infos ??= <DiscoverConnectionInfo>[];
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

  /// Adds common incoming variations
  static void addIncomingVariations(
      String host, List<DiscoverConnectionInfo> infos) {
    infos
      ..add(DiscoverConnectionInfo(host, 993, ServerType.imap, isSecure: true))
      ..add(DiscoverConnectionInfo(host, 143, ServerType.imap, isSecure: false))
      ..add(DiscoverConnectionInfo(host, 995, ServerType.pop, isSecure: true))
      ..add(DiscoverConnectionInfo(host, 110, ServerType.pop, isSecure: false));
  }

  /// Adds commmon outgoing variations
  static void addOutgoingVariations(
      String host, List<DiscoverConnectionInfo> infos) {
    infos
      ..add(DiscoverConnectionInfo(host, 465, ServerType.smtp, isSecure: true))
      ..add(DiscoverConnectionInfo(host, 587, ServerType.smtp, isSecure: false))
      ..add(DiscoverConnectionInfo(host, 25, ServerType.smtp, isSecure: false));
  }

  /// Parses a Mozilla-compatible autoconfig file
  ///
  /// Compare: https://wiki.mozilla.org/Thunderbird:Autoconfiguration:ConfigFileFormat
  static ClientConfig? parseClientConfig(String definition) {
    //print(definition);
    final config = ClientConfig();
    try {
      final document = xml.XmlDocument.parse(definition);
      for (final node in document.children) {
        if (node is xml.XmlElement && node.name.local == 'clientConfig') {
          final versionAttributes =
              node.attributes.where((a) => a.name.local == 'version');
          if (versionAttributes.isNotEmpty) {
            config.version = versionAttributes.first.value;
          } else {
            config.version = '1.1';
          }
          final providerNodes = node.children.where(
              (c) => c is xml.XmlElement && c.name.local == 'emailProvider');
          for (final providerNode in providerNodes) {
            if (providerNode is xml.XmlElement) {
              final provider = ConfigEmailProvider();
              // ignore: cascade_invocations
              provider.id = providerNode.getAttribute('id');
              for (final providerChild in providerNode.children) {
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
    } on Exception catch (e) {
      print(e);
      print('unable to parse: \n$definition\n');
    }
    if (config.isNotValid) {
      return null;
    }
    return config;
  }

  static ServerConfig _parseServerConfig(xml.XmlElement serverElement) {
    final server = ServerConfig()
      ..typeName = serverElement.getAttribute('type') ?? 'unknown';
    for (final childNode in serverElement.children) {
      if (childNode is xml.XmlElement) {
        final text = childNode.text;
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

/// Provides informatio about a connection
class DiscoverConnectionInfo {
  /// Creates a new info object
  DiscoverConnectionInfo(
    this.host,
    this.port,
    this.serverType, {
    required this.isSecure,
  });

  /// The host
  final String host;

  /// The port
  final int port;

  /// If a SSL connection is used
  final bool isSecure;

  /// The server type
  final ServerType serverType;

  /// The used socket, when not null the caller is required to close it
  Socket? socket;

  /// Checks if the server is ready to be used
  bool ready(ServerType type) => serverType == type && socket != null;
}
