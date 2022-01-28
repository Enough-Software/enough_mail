import '../mail/mail_account.dart';
import '../private/util/discover_helper.dart';

import 'client_config.dart';

/// Helps discovering email connection settings based on an email address.
///
/// Use [discover] to initiate the discovery process.
class Discover {
  Discover._();

  /// Tries to discover mail settings for the specified [emailAddress].
  ///
  /// Optionally set [forceSslConnection] to `true` when unencrypted
  /// connections should not be allowed.
  /// Set [isLogEnabled] to `true` to output debugging information during
  /// the discovery process.
  /// You can use the discovered client settings directly or by converting
  /// them to a [MailAccount] first with calling
  ///  `MailAccount.fromDiscoveredSettings()`.
  static Future<ClientConfig?> discover(String emailAddress,
      {bool forceSslConnection = false, bool isLogEnabled = false}) async {
    final config = await _discover(emailAddress, isLogEnabled);
    if (forceSslConnection && config != null) {
      if (config.preferredIncomingImapServer != null &&
          !config.preferredIncomingImapServer!.isSecureSocket) {
        config.preferredIncomingImapServer!.port = 993;
        config.preferredIncomingImapServer!.socketType = SocketType.ssl;
      }
      if (config.preferredIncomingPopServer != null &&
          !config.preferredIncomingPopServer!.isSecureSocket) {
        config.preferredIncomingPopServer!.port = 995;
        config.preferredIncomingPopServer!.socketType = SocketType.ssl;
      }
      if (config.preferredOutgoingSmtpServer != null &&
          !config.preferredOutgoingSmtpServer!.isSecureSocket) {
        config.preferredOutgoingSmtpServer!.port = 465;
        config.preferredOutgoingSmtpServer!.socketType = SocketType.ssl;
      }
    }
    return config;
  }

  /// Tries to complete the specified [partialAccount] information.
  ///
  /// This is useful when mail configuration settings cannot be discovered
  /// automatically and the user
  /// only provides some information such as the host domains of the incoming
  /// and outgoing servers.
  /// Warning: this method assumes that the host domain has been specified by
  /// the user and contains a corresponding assert statement.
  static Future<bool> complete(MailAccount partialAccount,
      {bool isLogEnabled = false}) async {
    final incoming = partialAccount.incoming?.serverConfig;
    assert(partialAccount.email?.isNotEmpty ?? false,
        'MailAccount requires email address');
    assert(incoming != null, 'MailAccount requires incoming server config');
    assert(incoming?.hostname != null,
        'MailAccount required incoming server host to be specified');
    final outgoing = partialAccount.outgoing?.serverConfig;
    assert(outgoing != null, 'MailAccount requires outgoing server config');
    assert(outgoing?.hostname != null,
        'MailAccount required outgoing server host to be specified');
    final infos = <DiscoverConnectionInfo>[];
    if (incoming!.port == null ||
        incoming.socketType == null ||
        incoming.type == null) {
      DiscoverHelper.addIncomingVariations(incoming.hostname!, infos);
    }
    if (outgoing!.port == null ||
        outgoing.socketType == null ||
        outgoing.type == null) {
      DiscoverHelper.addOutgoingVariations(outgoing.hostname!, infos);
    }
    if (infos.isNotEmpty) {
      final baseDomain =
          DiscoverHelper.getDomainFromEmail(partialAccount.email!);
      final clientConfig = await DiscoverHelper.discoverFromConnections(
          baseDomain, infos,
          isLogEnabled: isLogEnabled);
      if (clientConfig == null) {
        _log('Unable to discover remaining settings from $partialAccount',
            isLogEnabled);
        return false;
      }
      partialAccount.incoming!.serverConfig =
          clientConfig.preferredIncomingServer;
      partialAccount.outgoing!.serverConfig =
          clientConfig.preferredOutgoingServer;
    }
    return true;
  }

  static Future<ClientConfig?> _discover(
      String emailAddress, bool isLogEnabled) async {
    // [1] autodiscover from sub-domain, compare: https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
    final emailDomain = DiscoverHelper.getDomainFromEmail(emailAddress);
    var config = await DiscoverHelper.discoverFromAutoConfigSubdomain(
        emailAddress,
        domain: emailDomain,
        isLogEnabled: isLogEnabled);
    if (config == null) {
      final mxDomain = await DiscoverHelper.discoverMxDomain(emailDomain);
      _log('mxDomain for [$emailDomain] is [$mxDomain]', isLogEnabled);
      if (mxDomain != null && mxDomain != emailDomain) {
        config = await DiscoverHelper.discoverFromAutoConfigSubdomain(
            emailAddress,
            domain: mxDomain,
            isLogEnabled: isLogEnabled);
      }
      //print('querying ISP DB for $mxDomain');

      // [5] autodiscover from Mozilla ISP DB:
      // https://developer.mozilla.org/en-US/docs/Mozilla/Thunderbird/Autoconfiguration
      final hasMxDomain = mxDomain != null && mxDomain != emailDomain;
      config ??= await DiscoverHelper.discoverFromIspDb(emailDomain,
          isLogEnabled: isLogEnabled);
      if (hasMxDomain) {
        config ??= await DiscoverHelper.discoverFromIspDb(mxDomain,
            isLogEnabled: isLogEnabled);
      }

      // try to guess incoming and outgoing server names based on the domain
      final domains = hasMxDomain ? [emailDomain, mxDomain!] : [emailDomain];
      config ??= await DiscoverHelper.discoverFromCommonDomains(domains,
          isLogEnabled: isLogEnabled);
    }
    //print('got config $config for $mxDomain.');
    return _updateDisplayNames(config, emailDomain);
  }

  static ClientConfig? _updateDisplayNames(
      ClientConfig? config, String mailDomain) {
    final emailProviders = config?.emailProviders;
    if (emailProviders != null && emailProviders.isNotEmpty) {
      for (final provider in emailProviders) {
        if (provider.displayName != null) {
          provider.displayName =
              provider.displayName!.replaceFirst('%EMAILDOMAIN%', mailDomain);
        }
        if (provider.displayShortName != null) {
          provider.displayShortName = provider.displayShortName!
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
