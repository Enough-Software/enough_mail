import 'package:enough_mail/src/util/discover_helper.dart';

import 'client_config.dart';

class Discover {
  /// Tries to discover mail configuration settings for the specified [emailAddress].
  /// Optionally set [forceSslConnection] to `true` when unencrypted connections should not be allowed.
  /// Set [isLogEnabled] to `true` to output debugging information during the discovery process.
  /// You can use the discovered client settings directly or by converting them to
  /// a `MailAccount` first with calling  `MailAccount.fromDiscoveredSettings()`.
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
    final emailDomain = DiscoverHelper.getDomainFromEmail(emailAddress);
    var config = await DiscoverHelper.discoverFromAutoConfigSubdomain(
        emailAddress, emailDomain, isLogEnabled);
    if (config == null) {
      final mxDomain = await DiscoverHelper.discoverMxDomain(emailDomain);
      _log('mxDomain for [$emailDomain] is [$mxDomain]', isLogEnabled);
      if (mxDomain != null && mxDomain != emailDomain) {
        config = await DiscoverHelper.discoverFromAutoConfigSubdomain(
            emailAddress, mxDomain, isLogEnabled);
      }
      //print('querying ISP DB for $mxDomain');

      // [5] autodiscover from Mozilla ISP DB: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
      config ??= await DiscoverHelper.discoverFromIspDb(mxDomain, isLogEnabled);

      // try to guess incoming and outgoing server names based on the domain
      final domains = (mxDomain != null && mxDomain != emailDomain)
          ? [emailDomain, mxDomain]
          : [emailDomain];
      config ??=
          await DiscoverHelper.discoverFromVariations(domains, isLogEnabled);
    }
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
