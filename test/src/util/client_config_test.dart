import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

ServerConfig _server(ServerType type, int port, SocketType socketType) =>
    ServerConfig(
      type: type,
      hostname: 'mail.example.com',
      port: port,
      socketType: socketType,
      authentication: Authentication.passwordClearText,
      usernameType: UsernameType.emailLocalPart,
    );

void main() {
  test('emailLocalPart yields the local part', () {
    final config = _server(ServerType.imap, 143, SocketType.starttls);
    expect(config.getUserName('jane.doe@example.com'), 'jane.doe');
    expect(
      MailAccount.getLoginName('jane.doe@example.com', config),
      'jane.doe',
    );
  });

  test('enforceSecureSockets updates every preferred server', () {
    final imap = _server(ServerType.imap, 143, SocketType.starttls);
    final smtp = _server(ServerType.smtp, 587, SocketType.starttls);
    final config = ClientConfig(version: '1.1')
      ..addEmailProvider(
        ConfigEmailProvider()
          ..addIncomingServer(imap)
          ..addOutgoingServer(smtp),
      );
    expect(config.preferredIncomingServer, imap);
    expect(config.preferredOutgoingServer, smtp);

    config.enforceSecureSockets();

    for (final server in [
      config.preferredIncomingServer,
      config.preferredIncomingImapServer,
    ]) {
      expect(server?.socketType, SocketType.ssl);
      expect(server?.port, 993);
    }
    for (final server in [
      config.preferredOutgoingServer,
      config.preferredOutgoingSmtpServer,
    ]) {
      expect(server?.socketType, SocketType.ssl);
      expect(server?.port, 465);
    }
    final account = MailAccount.fromDiscoveredSettings(
      name: 'test',
      email: 'jane.doe@example.com',
      userName: 'Jane Doe',
      password: 'secret',
      config: config,
    );
    expect(account.incoming.serverConfig.socketType, SocketType.ssl);
    expect(account.outgoing.serverConfig.socketType, SocketType.ssl);
  });
}
