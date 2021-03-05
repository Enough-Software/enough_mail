import 'dart:convert' as convert;

import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:test/test.dart';

void main() {
  group('Quoted Printable decoding', () {
    test('encodings.quoted-printable header', () {
      var input =
          '=?utf-8?Q?Chat=3A?==?utf-8?Q?_?=oh=?utf-8?Q?_?==?utf-8?Q?hi=2C?='
          '=?utf-8?Q?__?=how=?utf-8?Q?_?=do=?utf-8?Q?_?=you=?utf-8?Q?_?==?utf-8?Q?do=3F?==?utf-8?Q?_?==?utf-8?Q?=3A-)?=';
      expect(MailCodec.decodeHeader(input), 'Chat: oh hi,  how do you do? :-)');
    });

    test('encodings.quoted-printable header no direct start', () {
      var input =
          ' =?utf-8?Q?Chat=3A?==?utf-8?Q?_?=oh=?utf-8?Q?_?==?utf-8?Q?hi=2C?='
          '=?utf-8?Q?__?=how=?utf-8?Q?_?=do=?utf-8?Q?_?=you=?utf-8?Q?_?==?utf-8?Q?do=3F?==?utf-8?Q?_?==?utf-8?Q?=3A-)?=';
      expect(
          MailCodec.decodeHeader(input), ' Chat: oh hi,  how do you do? :-)');
    });

    test('encoding.iso-8859-1 quoted printable', () {
      var input = '=?iso-8859-1?Q?Bj=F6rn?= Tester <btester@domain.com>';
      expect(
          MailCodec.decodeHeader(input), 'Björn Tester <btester@domain.com>');
    });

    test('encoding.iso-8859-1 quoted printable not at start', () {
      var input = 'Tester =?iso-8859-1?Q?Bj=F6rn?= <btester@domain.com>';
      expect(
          MailCodec.decodeHeader(input), 'Tester Björn <btester@domain.com>');
    });

    test('encoding.UTF-8.QuotedPrintable with several codes', () {
      var input = '=?utf-8?Q?=E2=80=93?=';
      expect(MailCodec.decodeHeader(input),
          isNotNull); // this results in a character - which for some reasons cannot be pasted as Dart code
    });
    test('encoding.US-ASCII.QuotedPrintable', () {
      var input = '=?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>';
      expect(MailCodec.decodeHeader(input), 'Keith Moore <moore@cs.utk.edu>');
    });

    test('encoding.UTF-8.QuotedPrintable with line break', () {
      var input = 'Viele Gr</span>=C3=BC=C3=9Fe</p=\r\n'
          '>';
      expect(MailCodec.quotedPrintable.decodeText(input, convert.utf8),
          'Viele Gr</span>üße</p>');
    });

    test('encoding latin1.QuotedPrintable', () {
      final input = 'jeden Tag =E4ndern k=F6nnen';
      expect(MailCodec.quotedPrintable.decodeText(input, convert.Latin1Codec()),
          'jeden Tag ändern können');
    });
  });

  group('Quoted Printable encoding', () {
    test('encodeHeader.quoted-printable with ASCII input', () {
      var input = 'Hello World';
      expect(MailCodec.quotedPrintable.encodeHeader(input), 'Hello World');
    });
    test('encodeHeader.quoted-printable with UTF8 input', () {
      var input = 'Hello Wörld';
      expect(MailCodec.quotedPrintable.encodeHeader(input),
          'Hello W=?utf8?Q?=C3=B6?=rld');
      // counter test:
      expect(
          MailCodec.decodeHeader('Hello W=?UTF8?Q?=C3=B6?=rld'), 'Hello Wörld');
    });

    test('encodeText.quoted-printable with UTF8 and = input', () {
      var input =
          'Hello Wörld. This is a long text without linebreak and this contains the formula c^2=a^2+b^2.';
      expect(MailCodec.quotedPrintable.encodeText(input),
          'Hello W=C3=B6rld. This is a long text without linebreak and this contains t=\r\nhe formula c^2=3Da^2+b^2.');
      // counter test:
      expect(
          MailCodec.quotedPrintable.decodeText(
              'Hello W=C3=B6rld. This is a long text without linebreak and this contains t=\r\nhe formula c^2=3Da^2+b^2.',
              convert.utf8),
          'Hello Wörld. This is a long text without linebreak and this contains the formula c^2=a^2+b^2.');
    });

    test('encodeText.quoted-printable \r\n line breaks', () {
      var input =
          'Hello Wörld.\r\nThis is a long text with\r\na linebreak and this contains the formula c^2=a^2+b^2.';
      expect(MailCodec.quotedPrintable.encodeText(input),
          'Hello W=C3=B6rld.\r\nThis is a long text with\r\na linebreak and this contains the formula c^2=3Da^2+b^2.');
      // counter test:
      expect(
          MailCodec.quotedPrintable.decodeText(
              MailCodec.quotedPrintable.encodeText(input), convert.utf8),
          input);
    });

    test('encodeText.quoted-printable \n line breaks', () {
      var input =
          'Hello Wörld.\nThis is a long text with\na linebreak and this contains the formula c^2=a^2+b^2.';
      expect(MailCodec.quotedPrintable.encodeText(input),
          'Hello W=C3=B6rld.\r\nThis is a long text with\r\na linebreak and this contains the formula c^2=3Da^2+b^2.');
    });
  });

  group('Q Encoding', () {
    group('Decode examples from https://tools.ietf.org/html/rfc2047#section-8',
        () {
      test('Decode space', () {
        var input = 'Keith_Moore';
        expect(
            MailCodec.quotedPrintable
                .decodeText(input, convert.utf8, isHeader: true),
            'Keith Moore');
      });

      test('Remove space between 2 encoded words', () {
        var input =
            '=?UTF-8?Q?=E5=9B=9E=E5=A4=8D=EF=BC=9ARe:_Nutzer-Anfrage_zu_deiner_A?= =?UTF-8?Q?nzeige_\"Brotbackmaschine_WK84300\"?=';
        expect(MailCodec.decodeHeader(input),
            '回复：Re: Nutzer-Anfrage zu deiner Anzeige "Brotbackmaschine WK84300"');
      });
    });
    group('Encode examples from https://tools.ietf.org/html/rfc2047#section-8',
        () {
      test('Encode space only when required', () {
        var input = 'Keith Moore';
        expect(MailCodec.quotedPrintable.encodeHeader(input), 'Keith Moore');
      });
    });
  });
}
