import 'package:test/test.dart';
import 'package:enough_mail/src/codecs/mail_codec.dart';

void main() {
  group('Wrap', () {
    test('wrap short input', () {
      var input = 'Hello World';
      expect(MailCodec.wrapText(input), 'Hello World');
    });

    test('wrap long input', () {
      var input =
          'Hello World! This is somewhat larger text that should span across multiple lines. This will be wrapped in the middle of a word unless accidentally this happens to fall on a space. Best regards, your unit test';
      var wrapped = MailCodec.wrapText(input);
      expect(
          wrapped,
          'Hello World! This is somewhat larger text that should span across multiple l\r\n'
          'ines. This will be wrapped in the middle of a word unless accidentally this \r\n'
          'happens to fall on a space. Best regards, your unit test');
    });

    test('wrap long input at word boundary', () {
      var input =
          'Hello World! This is somewhat larger text that should span across multiple lines. This will be wrapped in the middle of a word unless accidentally this happens to fall on a space. Best regards, your unit test';
      var wrapped = MailCodec.wrapText(input, wrapAtWordBoundary: true);
      expect(
          wrapped,
          'Hello World! This is somewhat larger text that should span across multiple \r\n'
          'lines. This will be wrapped in the middle of a word unless accidentally this \r\n'
          'happens to fall on a space. Best regards, your unit test');
    });

    test('wrap long input with line breaks', () {
      var input =
          'Hello World!\r\nThis is somewhat larger text\r\nthat should span across multiple lines.\r\nThis will be wrapped in the middle\r\nof a word unless accidentally\r\nthis happens to fall on a space. Best regards, your unit test';
      var wrapped = MailCodec.wrapText(input, wrapAtWordBoundary: true);
      expect(wrapped, input);
    });

    test('wrap long input with line breaks at beginning and end', () {
      var input =
          '\r\nHello World!\r\nThis is somewhat larger text\r\nthat should span across multiple lines.\r\nThis will be wrapped in the middle\r\nof a word unless accidentally\r\nthis happens to fall on a space. Best regards, your unit test\r\n';
      var wrapped = MailCodec.wrapText(input, wrapAtWordBoundary: true);
      expect(wrapped, input);
    });

    test('wrap long input with line break at 76', () {
      var input =
          '012345678901234567890123456789012345678901234567890123456789012345678901234\r\n56789';
      var wrapped = MailCodec.wrapText(input, wrapAtWordBoundary: true);
      expect(wrapped, input);
    });
  });

  group('Decode header', () {
    test('decode 2 consecutive encoded words', () {
      var input =
          '=?utf-8?Q?=D0=9E=EF=BB=BF=EF=BB=BF=EF=BB=BFf=EF=BB=BF=EF=BB=BF=EF?= =?utf-8?Q?=BB=BFf=EF=BB=BF=EF=BB=BF=EF=BB=BF=D1=96=EF=BB=BF=EF=BB=BF?= =?utf-8?Q?=EF=BB=BF=D1=81=EF=BB=BF=EF=BB=BF=EF=BB=BF=D0=B5=EF=BB=BF?= =?utf-8?Q?=EF=BB=BF=EF=BB=BF=E2=80=85=E2=80=8B=E2=80=8B=EF=BB=BF3=EF?= =?utf-8?Q?=BB=BF=EF=BB=BF=EF=BB=BF6=EF=BB=BF=EF=BB=BF=EF=BB=BF5?=';
      expect(
          MailCodec.decodeHeader(input), 'О﻿﻿﻿f﻿﻿f﻿﻿і﻿﻿﻿с﻿﻿﻿е﻿﻿﻿ ​​﻿3﻿﻿6﻿﻿5');
      input =
          '=?UTF-8?B?RXhrbHVzaXZlIEVpbmxhZHVuZzogSW5mbHVlbmNlci1WZXJidW5kIA==?= =?UTF-8?B?aW0gQ2hlY2s=?=';
      expect(MailCodec.decodeHeader(input),
          'Exklusive Einladung: Influencer-Verbund im Check');
      input =
          '=?UTF-8?B?4oCcUmVwLiBNYXR0IEdhZXR6IFN0YWZmZXIgQ2hlZXJlZCBvbiBDYXBpdG9sIFJpb3RlcnMgdmlhIFBhcmxlcuKAnSAtIFRoZSBCZQ==?= =?UTF-8?B?c3Qgb2YgTnV6emVsIE5ld3NsZXR0ZXIgVHVlLCBGZWIgMiAyMDIx?=';
      expect(MailCodec.decodeHeader(input),
          '“Rep. Matt Gaetz Staffer Cheered on Capitol Rioters via Parler” - The Best of Nuzzel Newsletter Tue, Feb 2 2021');
    });
    test('decode empty Q encoded header', () {
      var input = '=?utf-8?Q??=';
      expect(MailCodec.decodeHeader(input), '');
    });
    test('decode empty Base64 encoded header', () {
      var input = '=?utf-8?B??=';
      expect(MailCodec.decodeHeader(input), '');
    });
  });
}
