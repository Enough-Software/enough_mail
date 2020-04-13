import 'dart:convert' as convert;

import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:test/test.dart';

void main() {
  group('Quoted Printable decoding', () {
    test('encodings.quoted-printable header', () {
      var input =
          '=?utf-8?Q?Chat=3A?==?utf-8?Q?_?=oh=?utf-8?Q?_?==?utf-8?Q?hi=2C?='
          '=?utf-8?Q?__?=how=?utf-8?Q?_?=do=?utf-8?Q?_?=you=?utf-8?Q?_?==?utf-8?Q?do=3F?==?utf-8?Q?_?==?utf-8?Q?=3A-)?=';
      expect(MailCodec.decodeAny(input), 'Chat: oh hi,  how do you do? :-)');
    });

    test('encodings.quoted-printable header no direct start', () {
      var input =
          ' =?utf-8?Q?Chat=3A?==?utf-8?Q?_?=oh=?utf-8?Q?_?==?utf-8?Q?hi=2C?='
          '=?utf-8?Q?__?=how=?utf-8?Q?_?=do=?utf-8?Q?_?=you=?utf-8?Q?_?==?utf-8?Q?do=3F?==?utf-8?Q?_?==?utf-8?Q?=3A-)?=';
      expect(MailCodec.decodeAny(input), ' Chat: oh hi,  how do you do? :-)');
    });

    test('encoding.iso-8859-1 quoted printable', () {
      var input = '=?iso-8859-1?Q?Bj=F6rn?= Tester <btester@domain.com>';
      expect(MailCodec.decodeAny(input), 'Björn Tester <btester@domain.com>');
    });

    test('encoding.iso-8859-1 quoted printable not at start', () {
      var input = 'Tester =?iso-8859-1?Q?Bj=F6rn?= <btester@domain.com>';
      expect(MailCodec.decodeAny(input), 'Tester Björn <btester@domain.com>');
    });

    test('encoding.UTF-8.QuotedPrintable with several codes', () {
      var input = '=?utf-8?Q?=E2=80=93?=';
      expect(MailCodec.decodeAny(input),
          isNotNull); // this results in a character - which for some reasons cannot be pasted as Dart code
    });
    test('encoding.US-ASCII.QuotedPrintable', () {
      var input = '=?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>';
      expect(MailCodec.decodeAny(input), 'Keith Moore <moore@cs.utk.edu>');
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
      expect(MailCodec.decodeAny('Hello W=?UTF8?Q?=C3=B6?=rld'), 'Hello Wörld');
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
  });
}
