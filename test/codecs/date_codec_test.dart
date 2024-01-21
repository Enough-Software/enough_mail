import 'package:enough_mail/src/codecs/date_codec.dart';
import 'package:test/test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() {
  tz.initializeTimeZones();

  group('encode dates', () {
    test('encodeDate for UTC DateTime', () {
      expect(
        DateCodec.encodeDate(DateTime.utc(2022, 1, 7, 22, 18)),
        'Fri, 07 Jan 2022 22:18:00 -0000',
      );
    });
    test('encodeDate for DateTime east of Greenwich', () {
      expect(
        DateCodec.encodeDate(
          tz.TZDateTime(tz.getLocation('Europe/Berlin'), 2022, 1, 7, 22, 18),
        ),
        'Fri, 07 Jan 2022 22:18:00 +0100',
      );
    });
    test('encodeDate for DateTime west of Greenwich', () {
      expect(
        DateCodec.encodeDate(tz.TZDateTime(
          tz.getLocation('America/Panama'),
          2022,
          1,
          7,
          22,
          18,
        )),
        'Fri, 07 Jan 2022 22:18:00 -0500',
      );
    });
  });

  group('decode dates', () {
    test('decodeDate simple', () {
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0000'),
        DateTime.utc(2020, 2, 11, 22, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0100'),
        DateTime.utc(2020, 2, 11, 21, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0200'),
        DateTime.utc(2020, 2, 11, 20, 45).toLocal(),
      );
    });
    test('decodeDate with weekday', () {
      expect(
        DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0000'),
        DateTime.utc(2020, 2, 11, 22, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0100'),
        DateTime.utc(2020, 2, 11, 21, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0200'),
        DateTime.utc(2020, 2, 11, 20, 45).toLocal(),
      );
    });
    test('decodeDate with timezone name', () {
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0000 GMT'),
        DateTime.utc(2020, 2, 11, 22, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0100 CET'),
        DateTime.utc(2020, 2, 11, 21, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0200 EET'),
        DateTime.utc(2020, 2, 11, 20, 45).toLocal(),
      );
    });
    test('decodeDate with timezone name and weekday', () {
      expect(
        DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0000 GMT'),
        DateTime.utc(2020, 2, 11, 22, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('Tue, 11 Feb 2020 22:45 +0100 CET'),
        DateTime.utc(2020, 2, 11, 21, 45).toLocal(),
      );
      expect(
        DateCodec.decodeDate('11 Feb 2020 22:45 +0200 EET'),
        DateTime.utc(2020, 2, 11, 20, 45).toLocal(),
      );
    });
    test('decodeDate without timezone offset', () {
      expect(
        DateCodec.decodeDate('Thu, 26 Mar 2020 18:11:28'),
        DateTime.utc(2020, 3, 26, 18, 11, 28).toLocal(),
      );
    });
    test('decodeDate without timezone offset but timezone name', () {
      expect(
        DateCodec.decodeDate('Thu, 26 Mar 2020 18:11:28 GMT'),
        DateTime.utc(2020, 3, 26, 18, 11, 28).toLocal(),
      );
    });

    test('decodeDate with Zulu timezone', () {
      expect(
        DateCodec.decodeDate('Fri, 25 Dec 2020 08:57:44 Z'),
        DateTime.utc(2020, 12, 25, 8, 57, 44).toLocal(),
      );
    });

    test('decodeDate with only year-fraction', () {
      // while this is invalid, some mails are badly formatted:
      expect(
        DateCodec.decodeDate('Mon, 9 May 22 14:46:31 +0300 (MSK)'),
        DateTime.utc(2022, 05, 09, 11, 46, 31).toLocal(),
      );
    });
  });
}
