// ignore_for_file: lines_longer_than_80_chars

import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:event_bus/event_bus.dart';
import 'package:test/test.dart';

import '../mock_socket.dart';
import 'mock_pop_server.dart';
// cSpell:disable

late PopClient client;
bool _isLogEnabled = false;
late MockPopServer _mockServer;

void main() {
  setUp(() async {
    _log('setting up SmtpClient tests');
    final envVars = Platform.environment;
    _isLogEnabled = envVars['SMTP_LOG'] == 'true';

    client = PopClient(
      logName: 'enough.de',
      bus: EventBus(sync: true),
      isLogEnabled: _isLogEnabled,
    );

    final connection = MockConnection();
    client.connect(connection.socketClient,
        connectionInformation:
            const ConnectionInfo('pop.enough.de', 995, isSecure: true));
    _mockServer = MockPopServer(connection.socketServer);
    _mockServer.writeln('+OK ready <1896.697170952@dbc.mtview.ca.us>');

    /// allow server greeting to arrive
    await Future.delayed(const Duration(milliseconds: 200));

    _log('PopClient test setup complete');
  });

  test('PopClient.status()', () async {
    _mockServer.nextResponse = '+OK 2 320';
    final response = await client.status();
    expect(response.numberOfMessages, 2);
    expect(response.totalSizeInBytes, 320);
  });

  test('PopClient.list()', () async {
    _mockServer.nextResponse = '+OK 2 320\r\n\1 120\r\n2 200\r\n.\r\n';
    final response = await client.list();
    expect(response.length, 2);
    expect(response.first.id, 1);
    expect(response.first.sizeInBytes, 120);
    expect(response.last.id, 2);
    expect(response.last.sizeInBytes, 200);
  });

  test('PopClient.list(2)', () async {
    _mockServer.nextResponse = '+OK 2 200';
    final response = await client.list(2);
    expect(response.length, 1);
    expect(response.first.id, 2);
    expect(response.first.sizeInBytes, 200);
  });

  test('PopClient.list(3) fails', () async {
    _mockServer.nextResponse = '-ERR invalid ID';
    try {
      await client.list(3);
      fail('invalid list(3) should throw PopException');
    } on PopException catch (_) {
      // expected
    }
  });

  test('PopClient.uidList()', () async {
    _mockServer.nextResponse =
        '+OK unique-id listing follows\r\n\1 XSLKDSL\r\n2 QhdPYR:00WBw1Ph7x7\r\n.\r\n';
    final response = await client.uidList();
    expect(response.length, 2);
    expect(response.first.id, 1);
    expect(response.first.uid, 'XSLKDSL');
    expect(response.last.id, 2);
    expect(response.last.uid, 'QhdPYR:00WBw1Ph7x7');
  });

  test('PopClient.uidList(2)', () async {
    _mockServer.nextResponse = '+OK 2 QhdPYR:00WBw1Ph7x7';
    final response = await client.uidList(2);
    expect(response.length, 1);
    expect(response.first.id, 2);
    expect(response.first.uid, 'QhdPYR:00WBw1Ph7x7');
  });

  test('PopClient.uidList(3) fails', () async {
    _mockServer.nextResponse = '-ERR invalid ID';
    try {
      await client.uidList(3);
      fail('invalid uidList(3) should throw PopException');
    } on PopException catch (_) {
      // expected
    }
  });

  test('PopClient.login() valid', () async {
    _mockServer.nextResponses = ['+OK Please enter a password', '+OK welcome'];
    await client.login('name', 'password');
  });

  test('PopClient.login() invalid', () async {
    _mockServer.nextResponses = [
      '+OK Please enter a password',
      '-ERR password wrong'
    ];
    try {
      await client.login('name', 'password');
      fail('invalid login should throw PopException');
    } on PopException catch (_) {
      // expected
    }
  });

  test('PopClient.apop() valid', () async {
    expect(client.serverInfo.timestamp, '<1896.697170952@dbc.mtview.ca.us>');
    _mockServer.nextResponse = '+OK welcome';
    await client.loginWithApop('name', 'password');
  });

  test('PopClient.retrieve() simple message', () async {
    const from =
        MailAddress('Rita Levi-Montalcini', 'Rita.Levi-Montalcini@domain.com');
    final to = [
      const MailAddress('Rosalind Franklin', 'Rosalind.Franklin@domain.com')
    ];
    final expectedMessage = MessageBuilder.buildSimpleTextMessage(
        from, to, 'Today as well.\r\nOne more time:\r\nHello from enough_mail!',
        subject: 'enough_mail hello');
    _mockServer.nextResponse =
        '+OK some bytes follow\r\n$expectedMessage\r\n.\r\n';

    final message = await client.retrieve(120);
    expect(message.decodeSubject(), 'enough_mail hello');
    expect(message.from?.length, 1);
    expect(message.from?.first.personalName, 'Rita Levi-Montalcini');
    expect(message.from?.first.email, 'Rita.Levi-Montalcini@domain.com');
    expect(message.to?.length, 1);
    expect(message.to?.first.personalName, 'Rosalind Franklin');
    expect(message.to?.first.email, 'Rosalind.Franklin@domain.com');
  });

  test('PopClient.delete() success', () async {
    _mockServer.nextResponse = '+OK message deleted';
    await client.delete(2);
  });

  test('PopClient.delete() failed', () async {
    _mockServer.nextResponse = '-ERR unknown message ID';
    try {
      await client.delete(2);
      fail('invalid login should throw PopException');
    } on PopException catch (_) {
      // expected
    }
  });

  test('PopClient.noop()', () async {
    _mockServer.nextResponse = '+OK I am alive';
    await client.noop();
  });

  test('PopClient.reset()', () async {
    _mockServer.nextResponse =
        '+OK all messages marked as deleted are restored';
    await client.reset();
  });

  test('PopClient.quit()', () async {
    _mockServer.nextResponse = '+OK bye';
    await client.quit();
  });
}

void _log(String text) {
  if (_isLogEnabled) {
    print(text);
  }
}
