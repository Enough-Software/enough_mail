import 'package:test/test.dart';
import 'package:enough_mail/codecs/mail_codec.dart';

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
}
