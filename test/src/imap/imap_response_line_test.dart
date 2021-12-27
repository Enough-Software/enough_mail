import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';

void main() {
  test('ImapResponseLine.init() with simple response', () {
    const input = 'HELLO ()';
    final line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, input);
    expect(line.isWithLiteral, false);
  }); // test end

  test('ImapResponseLine.init() with complex response', () {
    const input = 'HELLO {12}';
    final line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, 'HELLO');
    expect(line.isWithLiteral, true);
    expect(line.literal, 12);
  }); // test end

  test(
      'ImapResponseLine.init() with complex response '
      'and plus after the numeric literal', () {
    const input = 'HELLO {12+}';
    final line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, 'HELLO');
    expect(line.isWithLiteral, true);
    expect(line.literal, 12);
  }); // test end

  test('ImapResponseLine with empty literal', () {
    const input = 'HELLO {0}';
    final line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, 'HELLO');
    expect(line.isWithLiteral, true);
    expect(line.literal, 0);
  });
}
