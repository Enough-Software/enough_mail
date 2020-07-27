import 'dart:async';
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
