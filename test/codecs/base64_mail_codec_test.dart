import 'dart:convert';

import 'package:enough_mail/codecs/base64_mail_codec.dart';
import 'package:test/test.dart';
import 'package:enough_mail/codecs/mail_codec.dart';

void main() {
  group('Base64 decoding', () {
    test('encoding.iso-8859-1 base64 directly repeated', () {
      var input =
          '=?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?==?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=';
      expect(MailCodec.decodeAny(input),
          'If you can read this you understand the example.');
    });

    test('encoding.UTF-8.Base64 with non-devidable-by-four base64 text', () {
      expect(MailCodec.base64.decodeText('8J+UkA', utf8), '🔐');
      var input = '=?utf-8?B?8J+UkA?= New Access Request - local.name';
      expect(MailCodec.decodeAny(input), '🔐 New Access Request - local.name');
    });

    test('encoding.US-ASCII.Base64', () {
      var input = '=?US-ASCII?B?S2VpdGggTW9vcmU?= <moore@cs.utk.edu>';
      expect(MailCodec.decodeAny(input), 'Keith Moore <moore@cs.utk.edu>');
      input = '=?US-ASCII?B?S2VpdGggTW9vcmU=?= <moore@cs.utk.edu>';
      expect(MailCodec.decodeAny(input), 'Keith Moore <moore@cs.utk.edu>');
    });
  });

  group('Base64 encoding', () {
    test('encodeHeader.base64 with ASCII input', () {
      var input = 'Hello World';
      expect(MailCodec.base64.encodeHeader(input), 'Hello World');
    });
    test('encodeHeader.base64 with UTF8 input', () {
      var input = 'Hello Wörld';
      expect(MailCodec.base64.encodeHeader(input), 'Hello W=?utf8?B?w7Y=?=rld');
      // counter test:
      expect(MailCodec.decodeAny('Hello W=?utf8?B?w7Y=?=rld'), 'Hello Wörld');
    });
  });
}
