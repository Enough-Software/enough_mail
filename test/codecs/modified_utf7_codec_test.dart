import 'dart:convert';

import 'package:test/test.dart';
import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:enough_mail/codecs/modified_utf7_codec.dart';

void main() {
  final codec = ModifiedUtf7Codec();
  final encoding = utf8;

  group('Modified UTF7 decoding', () {
    test('Simple case 1', () {
      var input = '&Jjo-!';
      expect(codec.decodeText(input, encoding), '☺!');
    });
    test('Simple case 2', () {
      var input = 'Hello, &ThZ1TA-';
      expect(codec.decodeText(input, encoding), 'Hello, 世界');
    });

    test('Encoded Ampersand', () {
      var input = 'hello&-goodbye';
      expect(codec.decodeText(input, encoding), 'hello&goodbye');
    });

    test('English, Japanese, and Chinese', () {
      var input = '~peter/mail/&ZeVnLIqe-/&U,BTFw-';
      expect(codec.decodeText(input, encoding), '~peter/mail/日本語/台北');
    });
  });

  group('Modified UTF7 encoding', () {
    test('Simple case 1', () {
      var input = '☺!';
      expect(codec.encodeText(input), '&Jjo-!');
    });
    test('Simple case 2', () {
      var input = 'Hello, 世界';
      expect(codec.encodeText(input), 'Hello, &ThZ1TA-');
    });

    test('Encoded Ampersand', () {
      var input = 'hello&goodbye';
      expect(codec.encodeText(input), 'hello&-goodbye');
    });

    test('English, Japanese, and Chinese', () {
      var input = '~peter/mail/日本語/台北';
      expect(codec.encodeText(input), '~peter/mail/&ZeVnLIqe-/&U,BTFw-');
    });

    test('quotes', () {
      var input = '""';
      expect(codec.encodeText(input), '""');
    });

    test('* wildcard', () {
      var input = '*';
      expect(codec.encodeText(input), '*');
    });

    test('% wildcard', () {
      var input = '%';
      expect(codec.encodeText(input), '%');
    });
  });
}
