import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  group('SmtpResponseLine.parse', () {
    test('code with space and text', () {
      final line = SmtpResponseLine.parse('250 OK');
      expect(line.code, 250);
      expect(line.message, 'OK');
      expect(line.type, SmtpResponseType.success);
    });

    test('code with hyphen and text (multiline reply)', () {
      final line = SmtpResponseLine.parse('250-PIPELINING');
      expect(line.code, 250);
      expect(line.message, 'PIPELINING');
    });

    test('bare code without text (RFC 5321 section 4.2)', () {
      final line = SmtpResponseLine.parse('250');
      expect(line.code, 250);
      expect(line.message, isEmpty);
      expect(line.type, SmtpResponseType.success);
    });

    test('code followed only by a separator', () {
      expect(SmtpResponseLine.parse('250 ').message, isEmpty);
      expect(SmtpResponseLine.parse('250-').message, isEmpty);
    });

    test('non-numeric prefix is kept as message with code 500', () {
      final line = SmtpResponseLine.parse('garbage line');
      expect(line.code, 500);
      expect(line.message, 'garbage line');
      expect(line.type, SmtpResponseType.fatalError);
    });

    test('line shorter than a reply code does not throw', () {
      final line = SmtpResponseLine.parse('25');
      expect(line.code, 500);
      expect(line.message, '25');
    });
  });

  group('SmtpResponse', () {
    test('multiline reply ending with a bare code', () {
      final response = SmtpResponse(['250-domain.com Hello', '250']);
      expect(response.responseLines.length, 2);
      expect(response.code, 250);
      expect(response.message, isEmpty);
      expect(response.isOkStatus, isTrue);
    });
  });
}
