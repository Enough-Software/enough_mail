import 'dart:io';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/smtp/smtp_command.dart';
import 'package:enough_mail/src/private/util/client_base.dart';
import 'package:test/test.dart';

import 'mock_socket.dart';

/// A socket whose writes never reach the wire
class _FailingSocket extends MockSocket {
  @override
  Future<void> flush() => Future.error(const SocketException('write failed'));
}

const _info = ConnectionInfo('mail.example.com', 143, isSecure: false);

void main() {
  test('SMTP: a command whose write fails is rejected', () async {
    final client = SmtpClient('test.example.com')
      ..connect(_FailingSocket(), connectionInformation: _info);
    await expectLater(
      client.sendCommand(SmtpCommand('NOOP')),
      throwsA(
        isA<SmtpException>().having(
          (e) => e.message,
          'message',
          startsWith('unable to send command'),
        ),
      ),
    );
  });

  test('POP: a command whose write fails is rejected', () async {
    final client = PopClient()
      ..connect(_FailingSocket(), connectionInformation: _info);
    await expectLater(
      client.noop(),
      throwsA(
        isA<PopException>().having(
          (e) => e.message,
          'message',
          startsWith('unable to send command'),
        ),
      ),
    );
  });
}
