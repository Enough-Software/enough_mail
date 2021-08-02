import 'package:test/test.dart';
import 'package:enough_mail/src/codecs/date_codec.dart';

void main() {
  group('decode dates', () {
    test('decodeDate simple', () {
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0000'),
          DateTime.utc(2020, 2, 11, 22, 45).toLocal());
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0100'),
          DateTime.utc(2020, 2, 11, 21, 45).toLocal());
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0200'),
          DateTime.utc(2020, 2, 11, 20, 45).toLocal());
    });
    test('decodeDate with weekday', () {
      expect(DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0000'),
          DateTime.utc(2020, 2, 11, 22, 45).toLocal());
      expect(DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0100'),
          DateTime.utc(2020, 2, 11, 21, 45).toLocal());
      expect(DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0200'),
          DateTime.utc(2020, 2, 11, 20, 45).toLocal());
    });
    test('decodeDate with timezone name', () {
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0000 GMT'),
          DateTime.utc(2020, 2, 11, 22, 45).toLocal());
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0100 CET'),
          DateTime.utc(2020, 2, 11, 21, 45).toLocal());
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0200 EET'),
          DateTime.utc(2020, 2, 11, 20, 45).toLocal());
    });
    test('decodeDate with timezone name and weekday', () {
      expect(DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0000 GMT'),
          DateTime.utc(2020, 2, 11, 22, 45).toLocal());
      expect(DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0100 CET'),
          DateTime.utc(2020, 2, 11, 21, 45).toLocal());
      expect(DateCodec.decodeDate('11 Feb 2020 22:45 +0200 EET'),
          DateTime.utc(2020, 2, 11, 20, 45).toLocal());
    });
    test('decodeDate without timezone offset', () {
      expect(DateCodec.decodeDate('Thu, 26 Mar 2020 18:11:28'),
          DateTime.utc(2020, 3, 26, 18, 11, 28).toLocal());
    });
    test('decodeDate without timezone offset but timezone name', () {
      expect(DateCodec.decodeDate('Thu, 26 Mar 2020 18:11:28 GMT'),
          DateTime.utc(2020, 3, 26, 18, 11, 28).toLocal());
    });

    test('decodeDate with Zulu timezone', () {
      expect(DateCodec.decodeDate('Fri, 25 Dec 2020 08:57:44 Z'),
          DateTime.utc(2020, 12, 25, 8, 57, 44).toLocal());
    });
  });
}
