import 'package:enough_mail/src/discover/client_config.dart';
import 'package:enough_mail/src/private/util/discover_helper.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  group('Autoconfigure tests', () {
    test('Autodiscover - parse 1&1 config', () async {
      const definition = '''
<clientConfig version="1.1">
 <emailProvider id="1und1.de">
  <!--  DSL customers  -->
  <domain>online.de</domain>
  <domain>onlinehome.de</domain>
  <domain>sofortstart.de</domain>
  <domain>sofort-start.de</domain>
  <domain>sofortsurf.de</domain>
  <domain>sofort-surf.de</domain>
  <domain>go4more.de</domain>
  <!--  Hosting customers, MX servers  -->
  <domain>kundenserver?.de</domain>
  <domain>schlund.de</domain>
  <displayName>1&1</displayName>
  <displayShortName>1&1</displayShortName>
  <incomingServer type="imap">
    <hostname>imap.1und1.de</hostname>
    <port>993</port>
    <socketType>SSL</socketType>
    <authentication>password-cleartext</authentication>
    <username>%EMAILADDRESS%</username>
  </incomingServer>
  <incomingServer type="imap">
    <hostname>imap.1und1.de</hostname>
    <port>143</port>
    <socketType>STARTTLS</socketType>
    <authentication>password-cleartext</authentication>
    <username>%EMAILADDRESS%</username>
  </incomingServer>
  <incomingServer type="pop3">
    <hostname>pop.1und1.de</hostname>
    <port>995</port>
    <socketType>SSL</socketType>
    <authentication>password-cleartext</authentication>
    <username>%EMAILADDRESS%</username>
  </incomingServer>
  <incomingServer type="pop3">
    <hostname>pop.1und1.de</hostname>
    <port>110</port>
    <socketType>STARTTLS</socketType>
    <authentication>password-cleartext</authentication>
    <username>%EMAILADDRESS%</username>
  </incomingServer>
  <outgoingServer type="smtp">
    <hostname>smtp.1und1.de</hostname>
    <port>587</port>
    <socketType>STARTTLS</socketType>
    <authentication>password-cleartext</authentication>
    <username>%EMAILADDRESS%</username>
  </outgoingServer>
  <documentation url="http://hilfe-center.1und1.de/access/search/go.php?t=e698123"/>
  <!--

          Kundenservice: +49-721-96-00
          Presse: +49-2602-96-1276 <presse@1und1.de>
        
  -->
 </emailProvider>
 <webMail>
  <loginPage url="https://webmailer.1und1.de/"/>
  <loginPageInfo url="https://webmailer.1und1.de/">
   <username>%EMAILADDRESS%</username>
   <usernameField id="emaillogin.Username"/>
   <passwordField id="emaillogin.Password"/>
   <loginButton id="save"/>
 </loginPageInfo>
 </webMail>
</clientConfig>
''';
      final config = DiscoverHelper.parseClientConfig(definition);
      expect(config?.version, '1.1');
      expect(config?.emailProviders?.length, 1);
      final provider = config?.emailProviders?.first;
      expect(provider?.id, '1und1.de');
      expect(provider?.domains?.length, 9);
      expect(provider?.domains?[0], 'online.de');
      expect(provider?.domains?[1], 'onlinehome.de');
      expect(provider?.domains?[2], 'sofortstart.de');
      expect(provider?.domains?[3], 'sofort-start.de');
      expect(provider?.domains?[4], 'sofortsurf.de');
      expect(provider?.domains?[5], 'sofort-surf.de');
      expect(provider?.domains?[6], 'go4more.de');
      expect(provider?.domains?[7], 'kundenserver?.de');
      expect(provider?.domains?[8], 'schlund.de');
      expect(provider?.displayName, '1&1');
      expect(provider?.displayShortName, '1&1');
      expect(provider?.incomingServers?.length, 4);

      var server = provider?.incomingServers?[0];
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'imap.1und1.de');
      expect(server?.port, 993);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = config?.preferredIncomingServer;
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'imap.1und1.de');
      expect(server?.port, 993);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = config?.preferredIncomingImapServer;
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'imap.1und1.de');
      expect(server?.port, 993);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = config?.preferredIncomingPopServer;
      expect(server?.type, ServerType.pop);
      expect(server?.typeName, 'pop');
      expect(server?.hostname, 'pop.1und1.de');
      expect(server?.port, 995);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = config?.preferredOutgoingServer;
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'smtp.1und1.de');
      expect(server?.port, 587);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = config?.preferredOutgoingSmtpServer;
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'smtp.1und1.de');
      expect(server?.port, 587);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[1];
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'imap.1und1.de');
      expect(server?.port, 143);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[2];
      expect(server?.type, ServerType.pop);
      expect(server?.typeName, 'pop');
      expect(server?.hostname, 'pop.1und1.de');
      expect(server?.port, 995);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[3];
      expect(server?.type, ServerType.pop);
      expect(server?.typeName, 'pop');
      expect(server?.hostname, 'pop.1und1.de');
      expect(server?.port, 110);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      expect(provider?.outgoingServers?.length, 1);
      server = provider?.outgoingServers?[0];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'smtp.1und1.de');
      expect(server?.port, 587);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      expect(
        provider?.documentationUrl,
        'http://hilfe-center.1und1.de/access/search/go.php?t=e698123',
      );

      //expect(awesome.isAwesome, isTrue);
    });

    test('Autodiscover - parse systemschmiede config', () async {
      const definition = '''
<?xml version="1.0" encoding="UTF-8"?>
<clientConfig version="1.1">
  <emailProvider id="exdomain">
    <domain>%EMAILDOMAIN%</domain>
    <displayName>%EMAILDOMAIN% Mail</displayName>
    <displayShortName>One.com</displayShortName>
    <incomingServer type="imap">
      <hostname>imap.one.com</hostname>
      <port>993</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <incomingServer type="imap">
      <hostname>imap.one.com</hostname>
      <port>143</port>
      <socketType>plain</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <incomingServer type="pop3">
      <hostname>pop.one.com</hostname>
      <port>995</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <incomingServer type="pop3">
      <hostname>pop.one.com</hostname>
      <port>110</port>
      <socketType>plain</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </incomingServer>
    <outgoingServer type="smtp">
      <hostname>send.one.com</hostname>
      <port>587</port>
      <socketType>SSL</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    <outgoingServer type="smtp">
      <hostname>send.one.com</hostname>
      <port>2525</port>
      <socketType>STARTTLS</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    <outgoingServer type="smtp">
      <hostname>send.one.com</hostname>
      <port>25</port>
      <socketType>STARTTLS</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    <outgoingServer type="smtp">
      <hostname>send.one.com</hostname>
      <port>2525</port>
      <socketType>plain</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    <outgoingServer type="smtp">
      <hostname>send.one.com</hostname>
      <port>25</port>
      <socketType>plain</socketType>
      <authentication>password-cleartext</authentication>
      <username>%EMAILADDRESS%</username>
    </outgoingServer>
    <documentation url="https://www.one.com/en/support/guide/mail/setting-up-thunderbird">
      <descr lang="en">Thunderbird settings Page</descr>
    </documentation>
  </emailProvider>
</clientConfig>
''';
      final config = DiscoverHelper.parseClientConfig(definition);
      expect(config?.version, '1.1');
      expect(config?.emailProviders?.length, 1);
      final provider = config?.emailProviders?.first;
      expect(provider?.id, 'exdomain');
      expect(provider?.domains?.length, 1);
      expect(provider?.domains?[0], '%EMAILDOMAIN%');
      expect(provider?.displayName, '%EMAILDOMAIN% Mail');
      expect(provider?.displayShortName, 'One.com');
      expect(provider?.incomingServers?.length, 4);

      var server = provider?.incomingServers?[0];
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'imap.one.com');
      expect(server?.port, 993);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[1];
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'imap.one.com');
      expect(server?.port, 143);
      expect(server?.socketType, SocketType.plain);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[2];
      expect(server?.type, ServerType.pop);
      expect(server?.typeName, 'pop');
      expect(server?.hostname, 'pop.one.com');
      expect(server?.port, 995);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[3];
      expect(server?.type, ServerType.pop);
      expect(server?.typeName, 'pop');
      expect(server?.hostname, 'pop.one.com');
      expect(server?.port, 110);
      expect(server?.socketType, SocketType.plain);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      expect(provider?.outgoingServers?.length, 5);
      server = provider?.outgoingServers?[0];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'send.one.com');
      expect(server?.port, 587);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.outgoingServers?[1];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'send.one.com');
      expect(server?.port, 2525);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.outgoingServers?[2];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'send.one.com');
      expect(server?.port, 25);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.outgoingServers?[3];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'send.one.com');
      expect(server?.port, 2525);
      expect(server?.socketType, SocketType.plain);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.outgoingServers?[4];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'send.one.com');
      expect(server?.port, 25);
      expect(server?.socketType, SocketType.plain);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      expect(
        provider?.documentationUrl,
        'https://www.one.com/en/support/guide/mail/setting-up-thunderbird',
      );
    });

    test('Autodiscover - parse freenet.de config', () async {
      const definition = '''
<clientConfig version="1.1">
<emailProvider id="freenet.de">
<domain>freenet.de</domain>
<displayName>Freenet Mail</displayName>
<displayShortName>Freenet</displayShortName>
<incomingServer type="imap">
<hostname>mx.freenet.de</hostname>
<port>993</port>
<socketType>SSL</socketType>
<authentication>password-encrypted</authentication>
<username>%EMAILADDRESS%</username>
</incomingServer>
<incomingServer type="pop3">
<hostname>mx.freenet.de</hostname>
<port>995</port>
<socketType>SSL</socketType>
<authentication>password-cleartext</authentication>
<username>%EMAILADDRESS%</username>
</incomingServer>
<outgoingServer type="smtp">
<hostname>mx.freenet.de</hostname>
<port>587</port>
<socketType>STARTTLS</socketType>
<authentication>password-encrypted</authentication>
<username>%EMAILADDRESS%</username>
</outgoingServer>
<documentation url="http://email-hilfe.freenet.de/documents/Beitrag/15916/einstellungen-serverdaten-fuer-alle-e-mail-programme">
<descr lang="de">Allgemeine Beschreibung der Einstellungen</descr>
<descr lang="en">Generic settings page</descr>
</documentation>
<documentation url="http://email-hilfe.freenet.de/documents/Beitrag/15808/thunderbird-e-mail-empfang-versand-einrichten-ueber-imap">
<descr lang="de">TB 2.0 IMAP-Einstellungen</descr>
<descr lang="en">TB 2.0 IMAP settings</descr>
</documentation>
</emailProvider>
</clientConfig>
''';
      final config = DiscoverHelper.parseClientConfig(definition);
      expect(config?.version, '1.1');
      expect(config?.emailProviders?.length, 1);
      final provider = config?.emailProviders?.first;
      expect(provider?.id, 'freenet.de');
      expect(provider?.domains?.length, 1);
      expect(provider?.domains?[0], 'freenet.de');
      expect(provider?.displayName, 'Freenet Mail');
      expect(provider?.displayShortName, 'Freenet');
      expect(provider?.incomingServers?.length, 2);

      var server = provider?.incomingServers?[0];
      expect(server?.type, ServerType.imap);
      expect(server?.typeName, 'imap');
      expect(server?.hostname, 'mx.freenet.de');
      expect(server?.port, 993);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordEncrypted);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      server = provider?.incomingServers?[1];
      expect(server?.type, ServerType.pop);
      expect(server?.typeName, 'pop');
      expect(server?.hostname, 'mx.freenet.de');
      expect(server?.port, 995);
      expect(server?.socketType, SocketType.ssl);
      expect(server?.authentication, Authentication.passwordClearText);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      expect(provider?.outgoingServers?.length, 1);
      server = provider?.outgoingServers?[0];
      expect(server?.type, ServerType.smtp);
      expect(server?.typeName, 'smtp');
      expect(server?.hostname, 'mx.freenet.de');
      expect(server?.port, 587);
      expect(server?.socketType, SocketType.starttls);
      expect(server?.authentication, Authentication.passwordEncrypted);
      expect(server?.username, '%EMAILADDRESS%');
      expect(server?.usernameType, UsernameType.emailAddress);

      expect(
        provider?.documentationUrl,
        'http://email-hilfe.freenet.de/documents/Beitrag/15916/einstellungen-serverdaten-fuer-alle-e-mail-programme',
      );
    });
  });
}
