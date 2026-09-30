import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/uint8_list_reader.dart';
import 'package:test/test.dart';

Uint8List _bytes(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  group('Uint8ListReader.readLinesToCrLfDotCrLfSequence', () {
    test('recognizes an empty multi-line response', () {
      final reader = Uint8ListReader()..add(_bytes('+OK 0 messages\r\n.\r\n'));
      expect(reader.readLine(), '+OK 0 messages');
      expect(reader.readLinesToCrLfDotCrLfSequence(), ['']);
      expect(reader.isAvailable(1), isFalse);
    });

    test('consumes the terminator completely', () {
      final reader = Uint8ListReader()
        ..add(_bytes('+OK\r\n1 100\r\n2 200\r\n.\r\n+OK next'));
      expect(reader.readLine(), '+OK');
      expect(reader.readLinesToCrLfDotCrLfSequence(), ['1 100', '2 200']);
      expect(reader.readLine(), isNull);
      reader.add(_bytes('\r\n'));
      expect(reader.readLine(), '+OK next');
    });

    test('handles data split across chunks and dot-stuffed lines', () {
      final reader = Uint8ListReader()..add(_bytes('+OK\r\nline 1\r'));
      expect(reader.readLine(), '+OK');
      expect(reader.readLinesToCrLfDotCrLfSequence(), isNull);
      reader.add(_bytes('\n..stuffed\r\n.\r'));
      expect(reader.readLinesToCrLfDotCrLfSequence(), isNull);
      reader.add(_bytes('\n'));
      expect(reader.readLinesToCrLfDotCrLfSequence(), ['line 1', '..stuffed']);
    });

    test('scans a large message in linear time', () {
      final reader = Uint8ListReader()..add(_bytes('+OK\r\n'));
      expect(reader.readLine(), '+OK');
      final chunk = _bytes('${'x' * 1000}\r\n' * 60);
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 400; i++) {
        reader.add(chunk);
        expect(reader.readLinesToCrLfDotCrLfSequence(), isNull);
      }
      reader.add(_bytes('.\r\n'));
      final lines = reader.readLinesToCrLfDotCrLfSequence();
      stopwatch.stop();
      expect(lines, hasLength(400 * 60));
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
    });
  });

  group('PopClient', () {
    late ServerSocket server;

    setUp(() async {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() => server.close());

    test('LIST and UIDL on an empty mailbox complete', () async {
      server.listen((socket) {
        socket.write('+OK POP3 ready\r\n');
        socket.listen((data) {
          final request = String.fromCharCodes(data);
          if (request.startsWith('LIST') || request.startsWith('UIDL')) {
            socket.write('+OK 0 messages\r\n.\r\n');
          } else {
            socket.write('+OK\r\n');
          }
        });
      });
      final client = PopClient();
      await client.connectToServer(
        server.address.address,
        server.port,
        isSecure: false,
      );
      expect(await client.list(), isEmpty);
      expect(await client.uidList(), isEmpty);
      await client.disconnect();
    });
  });
}
