import 'dart:convert';

import 'package:enough_mail/src/codecs/modified_utf7_codec.dart';
import 'package:test/test.dart';

void main() {
  const codec = ModifiedUtf7Codec();
  const encoding = utf8;

  group('Modified UTF7 decoding', () {
    test('Simple case 1', () {
      const input = '&Jjo-!';
      expect(codec.decodeText(input, encoding), '☺!');
    });
    test('Simple case 2', () {
      const input = 'Hello, &ThZ1TA-';
      expect(codec.decodeText(input, encoding), 'Hello, 世界');
    });

    test('Encoded Ampersand', () {
      const input = 'hello&-goodbye';
      expect(codec.decodeText(input, encoding), 'hello&goodbye');
    });

    test('English, Japanese, and Chinese', () {
      const input = '~peter/mail/&ZeVnLIqe-/&U,BTFw-';
      expect(codec.decodeText(input, encoding), '~peter/mail/日本語/台北');
    });
  });

  group('Modified UTF7 encoding', () {
    test('Simple case 1', () {
      const input = '☺!';
      expect(codec.encodeText(input), '&Jjo-!');
    });
    test('Simple case 2', () {
      const input = 'Hello, 世界';
      expect(codec.encodeText(input), 'Hello, &ThZ1TA-');
    });

    test('Encoded Ampersand', () {
      const input = 'hello&goodbye';
      expect(codec.encodeText(input), 'hello&-goodbye');
    });

    test('English, Japanese, and Chinese', () {
      const input = '~peter/mail/日本語/台北';
      expect(codec.encodeText(input), '~peter/mail/&ZeVnLIqe-/&U,BTFw-');
    });

    test('quotes', () {
      const input = '""';
      expect(codec.encodeText(input), '""');
    });

    test('* wildcard', () {
      const input = '*';
      expect(codec.encodeText(input), '*');
    });

    test('% wildcard', () {
      const input = '%';
      expect(codec.encodeText(input), '%');
    });
  });
}
