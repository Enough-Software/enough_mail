import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

const _header =
    'From: a@example.com\r\n'
    'Content-Type: multipart/alternative; boundary="b"\r\n'
    '\r\n';

const _spoofed =
    '$_header'
    '--b\r\n'
    'Content-Type: text/plain\r\n'
    '\r\n'
    'line one foo--b\r\n'
    'Content-Type: text/html\r\n'
    '\r\n'
    'INJECTED\r\n'
    '--b--\r\n';

void main() {
  group('multipart boundaries', () {
    test('delimiter in the middle of a line is content, not a boundary', () {
      for (final message in [
        MimeMessage.parseFromText(_spoofed),
        MimeMessage.parseFromData(utf8.encode(_spoofed)),
      ]) {
        expect(message.parts, hasLength(1));
        expect(message.decodeTextHtmlPart(), isNull);
        expect(message.decodeTextPlainPart(), contains('INJECTED'));
      }
    });

    test('a boundary that is a prefix of another boundary does not match', () {
      const text =
          '$_header'
          '--b\r\nContent-Type: text/plain\r\n\r\nfirst\r\n'
          '--b2\r\nstill first\r\n'
          '--b\r\nContent-Type: text/plain\r\n\r\nsecond\r\n'
          '--b--\r\n';
      for (final message in [
        MimeMessage.parseFromText(text),
        MimeMessage.parseFromData(utf8.encode(text)),
      ]) {
        expect(message.parts, hasLength(2));
        expect(
          message.parts![0].decodeContentText(),
          'first\r\n--b2\r\nstill first\r\n',
        );
        expect(message.parts![1].decodeContentText(), 'second\r\n');
      }
    });

    test('transport padding after the delimiter is tolerated', () {
      const text =
          '$_header'
          '--b \t\r\nContent-Type: text/plain\r\n\r\nfirst\r\n'
          '--b-- \r\nepilogue\r\n';
      for (final message in [
        MimeMessage.parseFromText(text),
        MimeMessage.parseFromData(utf8.encode(text)),
      ]) {
        expect(message.parts, hasLength(1));
        expect(message.parts![0].decodeContentText(), 'first\r\n');
      }
    });

    test('binary path finds small parts and a missing closing delimiter', () {
      final boundary = 'x' * 70;
      final text =
          'Content-Type: multipart/mixed; boundary="$boundary"\r\n\r\n'
          '--$boundary\r\nContent-Type: text/plain\r\n\r\n${'a' * 300}\r\n'
          '--$boundary\r\nContent-Type: text/plain\r\n\r\ntiny\r\n';
      final message = MimeMessage.parseFromData(utf8.encode(text));
      expect(message.parts, hasLength(2));
      expect(message.parts![1].decodeContentText(), 'tiny\r\n');
    });

    test('message/rfc822 without a header separator does not throw', () {
      const text = 'Content-Type: message/rfc822\r\n\r\nSubject: x';
      expect(() => MimeMessage.parseFromText(text), returnsNormally);
      expect(
        () => MimeMessage.parseFromData(utf8.encode(text)),
        returnsNormally,
      );
      const noBody = 'Content-Type: message/rfc822\r\n\r\n';
      expect(() => MimeMessage.parseFromText(noBody), returnsNormally);
      expect(
        () => MimeMessage.parseFromData(utf8.encode(noBody)),
        returnsNormally,
      );
    });

    test('binary rfc822 boundary quote search stays in the header', () {
      const text =
          'Content-Type: message/rfc822\r\n\r\n'
          'Content-Type: multipart/mixed; boundary="abc\r\n\r\nbody with "quote';
      expect(
        () => MimeMessage.parseFromData(utf8.encode(text)),
        returnsNormally,
      );
    });

    test('deeply nested multiparts are parsed up to the depth limit', () {
      final buffer = StringBuffer();
      const depth = MimeData.maxNestingDepth + 20;
      for (var i = 0; i < depth; i++) {
        buffer.write(
          'Content-Type: multipart/mixed; boundary="b$i"\r\n\r\n--b$i\r\n',
        );
      }
      buffer.write('Content-Type: text/plain\r\n\r\ndeep\r\n');
      for (var i = depth - 1; i >= 0; i--) {
        buffer.write('--b$i--\r\n');
      }
      final text = buffer.toString();
      for (final message in [
        MimeMessage.parseFromText(text),
        MimeMessage.parseFromData(utf8.encode(text)),
      ]) {
        var part = message as MimePart;
        var level = 0;
        while (part.parts?.isNotEmpty ?? false) {
          part = part.parts!.first;
          level++;
        }
        expect(level, MimeData.maxNestingDepth);
      }
    });
  });
}
