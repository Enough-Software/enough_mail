import 'package:enough_mail/src/smtp/smtp_command.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:event_bus/event_bus.dart';
import 'package:enough_mail/enough_mail.dart';

import '../mock_socket.dart';
import 'mock_smtp_server.dart';

SmtpClient client;
bool _isLogEnabled = false;
String _smtpUser;
String _smtpPassword;
MockSmtpServer _mockServer;

void main() {
  setUp(() async {
    if (client != null) {
      return;
    }
    _log('setting up ImapClient tests');
    var envVars = Platform.environment;

    var smtpPort = 587; // 25;
    String smtpHost;
    var useRealConnection =
        (!envVars.containsKey('SMTP_USE') || envVars['SMTP_USE'] == 'true') &&
            envVars.containsKey('SMTP_HOST') &&
            envVars.containsKey('SMTP_USER') &&
            envVars.containsKey('SMTP_PASSWORD');
    if (useRealConnection) {
      if (envVars.containsKey('SMTP_LOG')) {
        _isLogEnabled = (envVars['SMTP_LOG'] == 'true');
      } else {
        _isLogEnabled = true;
      }
      smtpHost = envVars['SMTP_HOST'];
      _smtpUser = envVars['SMTP_USER'];
      _smtpPassword = envVars['SMTP_PASSWORD'];
      if (envVars.containsKey('SMTP_PORT')) {
        smtpPort = int.parse(envVars['SMTP_PORT']);
      }
    } else if (envVars.containsKey('SMTP_LOG')) {
      _isLogEnabled = (envVars['SMTP_LOG'] == 'true');
    }
    client = SmtpClient('coi-dev.org',
        bus: EventBus(sync: true), isLogEnabled: _isLogEnabled);

    if (useRealConnection) {
      await client.connectToServer(smtpHost, smtpPort,
          isSecure: (smtpPort != 25));
      //capResponse = await client.login(imapUser, imapPassword);
    } else {
      _smtpUser = 'testuser';
      _smtpPassword = 'testpassword';
      var connection = MockConnection();
      client.connect(connection.socketClient);
      _mockServer = MockSmtpServer.connect(
          connection.socketServer, _smtpUser, _smtpPassword);
      client.serverInfo = SmtpServerInfo();
      //   capResponse = await client.login("testuser", "testpassword");
    }

    _log('SmtpClient test setup complete');
  });

  test('SmtpClient EHLO', () async {
    if (_mockServer != null) {
      _mockServer.nextResponse = '220 domain.com ESMTP Postfix\r\n'
          '250-domain.com\r\n'
          '250-PIPELINING\r\n'
          '250-SIZE 200000000\r\n'
          '250-ETRN\r\n'
          '250-AUTH PLAIN LOGIN OAUTHBEARER\r\n'
          '250-AUTH=PLAIN LOGIN OAUTHBEARER\r\n'
          '250-ENHANCEDSTATUSCODES\r\n'
          '250-8BITMIME\r\n'
          '250 DSN';
    }
    var response = await client.ehlo();
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 250);
  });

  test('SmtpClient login', () async {
    if (_mockServer != null) {
      _mockServer.nextResponse = '235 2.7.0 Authentication successful';
    }
    var response = await client.login(_smtpUser, _smtpPassword);
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 235);
  });

  test('SmtpClient sendMessage', () async {
    var from =
        MailAddress('Rita Levi-Montalcini', 'Rita.Levi-Montalcini@domain.com');
    var to = [MailAddress('Rosalind Franklin', 'Rosalind.Franklin@domain.com')];
    var message = MessageBuilder.buildSimpleTextMessage(from, to,
        'Today as well.\r\nOne more time:\r\nHello from Enough MailKit!',
        subject: 'enough_mail hello');
    var response = await client.sendMessage(message);
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 250);
  });

  test('SmtpClient quit', () async {
    var response = await client.quit();
    expect(response.type, SmtpResponseType.success);
    expect(response.code, 221);
  });

  test('SmtpClient with exception', () async {
    final command = DummySmtpCommand('example');
    try {
      final response = await client.sendCommand(DummySmtpCommand('example'));
      fail('sendCommand should throw. (but got: $response)');
    } catch (e, stackTrace) {
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
    throw this;
  }
}
