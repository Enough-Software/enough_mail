import 'package:enough_mail/src/util/discover_helper.dart';

import 'client_config.dart';

class Discover {
  static Future<ClientConfig> discover(String emailAddress,
      {bool forceSslConnection = false, bool isLogEnabled = false}) async {
    var config = await _discover(emailAddress, isLogEnabled);
    if (forceSslConnection && config != null) {
      if (config.preferredIncomingImapServer != null &&
          !config.preferredIncomingImapServer.isSecureSocket) {
        config.preferredIncomingImapServer.port = 993;
        config.preferredIncomingImapServer.socketType = SocketType.ssl;
      }
      if (config.preferredIncomingPopServer != null &&
          !config.preferredIncomingPopServer.isSecureSocket) {
        config.preferredIncomingPopServer.port = 995;
        config.preferredIncomingPopServer.socketType = SocketType.ssl;
      }
      if (config.preferredOutgoingSmtpServer != null &&
          !config.preferredOutgoingSmtpServer.isSecureSocket) {
        config.preferredOutgoingSmtpServer.port = 465;
        config.preferredOutgoingSmtpServer.socketType = SocketType.ssl;
      }
    }
    return config;
  }

  static Future<ClientConfig> _discover(
      String emailAddress, bool isLogEnabled) async {
    // [1] autodiscover from sub-domain, compare: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
    var emailDomain = DiscoverHelper.getDomainFromEmail(emailAddress);
    var config = await DiscoverHelper.discoverFromAutoConfigSubdomain(
        emailAddress, emailDomain, isLogEnabled);
    if (config != null) {
      return _updateDisplayNames(config, emailDomain);
    }
    var mxDomain = await DiscoverHelper.discoverMxDomain(emailDomain);
    _log('mxDomain for [$emailDomain] is [$mxDomain]', isLogEnabled);
    if (mxDomain != null && mxDomain != emailDomain) {
      config = await DiscoverHelper.discoverFromAutoConfigSubdomain(
          emailAddress, mxDomain, isLogEnabled);
      if (config != null) {
        return _updateDisplayNames(config, emailDomain);
      }
    }
    // TODO allow more autodiscover options:
    // [2] https://docs.microsoft.com/en-us/previous-versions/office/office-2010/cc511507(v=office.14)
    // [3] https://docs.microsoft.com/en-us/exchange/client-developer/exchange-web-services/autodiscover-for-exchange
    // [4] https://docs.microsoft.com/en-us/exchange/architecture/client-access/autodiscover
    // [6] by trying typical options like imap.$domain, mail.$domain, etc

    //print('querying ISP DB for $mxDomain');

    // [5] autodiscover from Mozilla ISP DB: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
    config = await DiscoverHelper.discoverFromIspDb(mxDomain, isLogEnabled);
    //print('got config $config for $mxDomain.');
    return _updateDisplayNames(config, emailDomain);
  }

  static ClientConfig _updateDisplayNames(
      ClientConfig config, String mailDomain) {
    if (config?.emailProviders?.isNotEmpty ?? false) {
      for (var provider in config.emailProviders) {
        if (provider.displayName != null) {
          provider.displayName =
              provider.displayName.replaceFirst('%EMAILDOMAIN%', mailDomain);
        }
        if (provider.displayShortName != null) {
          provider.displayShortName = provider.displayShortName
              .replaceFirst('%EMAILDOMAIN%', mailDomain);
        }
      }
    }
    return config;
  }

  static void _log(String text, bool isLogEnabled) {
    if (isLogEnabled) {
      print(text);
    }
  }
}
