import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/smtp_command.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:event_bus/event_bus.dart';
import 'package:test/test.dart';

import '../mock_socket.dart';
import 'mock_smtp_server.dart';

late SmtpClient client;
bool _isLogEnabled = false;
late String _smtpUser;
late String _smtpPassword;
late MockSmtpServer _mockServer;

void main() {
  setUp(() async {
    _log('setting up SmtpClient tests');
    final envVars = Platform.environment;
    _isLogEnabled = envVars['SMTP_LOG'] == 'true';

    client = SmtpClient('enough.de',
        bus: EventBus(sync: true), isLogEnabled: _isLogEnabled);

    _smtpUser = 'testuser';
    _smtpPassword = 'testpassword';
    final connection = MockConnection();
    client.connect(connection.socketClient,
        connectionInformation:
            const ConnectionInfo('dummy.domain.com', 587, isSecure: true));
    _mockServer = MockSmtpServer.connect(
        connection.socketServer, _smtpUser, _smtpPassword);
    _mockServer.writeln('220 domain.com ESMTP Postfix');

    //   capResponse = await client.login("testuser", "testpassword");

    _log('SmtpClient test setup complete');
  });

  test('SmtpClient EHLO', () async {
    _mockServer.nextResponse = '250-domain.com Hello\r\n'
        '250-PIPELINING\r\n'
        '250-SIZE 200000000\r\n'
        '250-ETRN\r\n'
        '250-AUTH PLAIN LOGIN XOAUTH2\r\n'
        '250-AUTH=PLAIN LOGIN XOAUTH2\r\n'
        '250-ENHANCEDSTATUSCODES\r\n'
        '250-8BITMIME\r\n'
        '250 DSN';
    final response = await client.ehlo();
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 250);
    expect(client.serverInfo.supports8BitMime, isTrue);
    expect(client.serverInfo.supportsAuth(AuthMechanism.plain), isTrue);
    expect(client.serverInfo.supportsAuth(AuthMechanism.login), isTrue);
    expect(client.serverInfo.supportsAuth(AuthMechanism.xoauth2), isTrue);
    expect(client.serverInfo.maxMessageSize, 200000000);
    expect(client.serverInfo.supports('PIPELINING'), isTrue);
    expect(client.serverInfo.supports('DSN'), isTrue);
    expect(client.serverInfo.supports('NOTTHERE'), isFalse);
  });

  test('SmtpClient login', () async {
    _mockServer.nextResponse = '235 2.7.0 Authentication successful';
    final response = await client.authenticate(_smtpUser, _smtpPassword);
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 235);
  });

  test('SmtpClient sendMessage', () async {
    final from =
        MailAddress('Rita Levi-Montalcini', 'Rita.Levi-Montalcini@domain.com');
    final to = [
      MailAddress('Rosalind Franklin', 'Rosalind.Franklin@domain.com')
    ];
    final message = MessageBuilder.buildSimpleTextMessage(
        from, to, 'Today as well.\r\nOne more time:\r\nHello from enough_mail!',
        subject: 'enough_mail hello');
    final response = await client.sendMessage(message);
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 250);
  });

  test('SmtpClient sendBdatMessage', () async {
    final from =
        MailAddress('Rita Levi-Montalcini', 'Rita.Levi-Montalcini@domain.com');
    final to = [
      MailAddress('Rosalind Franklin', 'Rosalind.Franklin@domain.com')
    ];
    final message = MessageBuilder.buildSimpleTextMessage(
        from, to, 'Today as well.\r\nOne more time:\r\nHello from enough_mail!',
        subject: 'enough_mail hello');
    final response = await client.sendChunkedMessage(message);
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 250);
  });

  test('SmtpClient quit', () async {
    final response = await client.quit();
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 221);
  });

  test('SmtpClient with exception', () async {
    try {
      final response = await client.sendCommand(DummySmtpCommand('example'));
      fail('sendCommand should throw. (but got: $response)');
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      expect(e, isA<DummySmtpCommand>());
    }
  });
}

void _log(String text) {
  if (_isLogEnabled) {
    print(text);
  }
}

class DummySmtpCommand extends SmtpCommand {
  DummySmtpCommand(String command) : super(command);
  @override
  String nextCommand(SmtpResponse response) {
    // ignore: only_throw_errors
    throw this;
  }
}
