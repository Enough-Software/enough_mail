import 'dart:convert';

import 'package:test/test.dart';
import 'package:enough_mail/encodings.dart';

void main() {
  test('encodings.quoted-printable header', () {
    var input =
        '=?utf-8?Q?Chat=3A?==?utf-8?Q?_?=oh=?utf-8?Q?_?==?utf-8?Q?hi=2C?='
        '=?utf-8?Q?__?=how=?utf-8?Q?_?=do=?utf-8?Q?_?=you=?utf-8?Q?_?==?utf-8?Q?do=3F?==?utf-8?Q?_?==?utf-8?Q?=3A-)?=';
    expect(
        EncodingsHelper.decodeAny(input), 'Chat: oh hi,  how do you do? :-)');
  });

  test('encodings.quoted-printable header no direct start', () {
    var input =
        ' =?utf-8?Q?Chat=3A?==?utf-8?Q?_?=oh=?utf-8?Q?_?==?utf-8?Q?hi=2C?='
        '=?utf-8?Q?__?=how=?utf-8?Q?_?=do=?utf-8?Q?_?=you=?utf-8?Q?_?==?utf-8?Q?do=3F?==?utf-8?Q?_?==?utf-8?Q?=3A-)?=';
    expect(
        EncodingsHelper.decodeAny(input), ' Chat: oh hi,  how do you do? :-)');
  });

  test('encoding.iso-8859-1 quoted printable', () {
    var input = '=?iso-8859-1?Q?Bj=F6rn?= Tester <btester@domain.com>';
    expect(
        EncodingsHelper.decodeAny(input), 'Björn Tester <btester@domain.com>');
  });

  test('encoding.iso-8859-1 quoted printable not at start', () {
    var input = 'Tester =?iso-8859-1?Q?Bj=F6rn?= <btester@domain.com>';
    expect(
        EncodingsHelper.decodeAny(input), 'Tester Björn <btester@domain.com>');
  });

  test('encoding.iso-8859-1 base64 directly repeated', () {
    var input = '=?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?==?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=';
    expect(
        EncodingsHelper.decodeAny(input), 'If you can read this you understand the example.');
  });
  

  test('encoding.UTF-8.QuotedPrintable with several codes', () {
    var input = '=?utf-8?Q?=E2=80=93?=';
    expect(EncodingsHelper.decodeAny(input),
        isNotNull); // this results in a character - which for some reasons cannot be pasted as Dart code
  });

  test('encoding.UTF-8.Base64 with non-devidable-by-four base64 text', () {
    expect(EncodingsHelper.decodeBase64('8J+UkA', utf8), '🔐');
    var input = '=?utf-8?B?8J+UkA?= New Access Request - local.name';
    expect(
        EncodingsHelper.decodeAny(input), '🔐 New Access Request - local.name');
  });

  test('encoding.US-ASCII.QuotedPrintable', () {
    var input = '=?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>';
    expect(EncodingsHelper.decodeAny(input), 'Keith Moore <moore@cs.utk.edu>');
  });

  test('encoding.US-ASCII.Base64', () {
    var input = '=?US-ASCII?B?S2VpdGggTW9vcmU?= <moore@cs.utk.edu>';
    expect(EncodingsHelper.decodeAny(input), 'Keith Moore <moore@cs.utk.edu>');
    input = '=?US-ASCII?B?S2VpdGggTW9vcmU=?= <moore@cs.utk.edu>';
    expect(EncodingsHelper.decodeAny(input), 'Keith Moore <moore@cs.utk.edu>');
  });

  test('decodeDate', () {
    expect(EncodingsHelper.decodeDate('11 Feb 2020 22:45 +0000'),
        DateTime.utc(2020, 2, 11, 22, 45));
    expect(EncodingsHelper.decodeDate('11 Feb 2020 22:45 +0100'),
        DateTime.utc(2020, 2, 11, 23, 45));
    expect(EncodingsHelper.decodeDate('11 Feb 2020 22:45 +0200'),
        DateTime.utc(2020, 2, 12, 0, 45));
  });
}
