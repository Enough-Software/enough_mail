import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:test/test.dart';

void main() {
  test('ImapResponseLine.init() with simple response', () {
    var input = 'HELLO ()';
    var line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, input);
    expect(line.isWithLiteral, false);
  }); // test end

  test('ImapResponseLine.init() with complex response', () {
    var input = 'HELLO {12}';
    var line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, 'HELLO');
    expect(line.isWithLiteral, true);
    expect(line.literal, 12);
  }); // test end

  test(
      'ImapResponseLine.init() with complex response and plus after the numeric literal',
      () {
    var input = 'HELLO {12+}';
    var line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, 'HELLO');
    expect(line.isWithLiteral, true);
    expect(line.literal, 12);
  }); // test end

  test('ImapResponseLine with empty literal', () {
    var input = 'HELLO {0}';
    var line = ImapResponseLine(input);
    expect(line.rawLine, input);
    expect(line.line, 'HELLO');
    expect(line.isWithLiteral, true);
    expect(line.literal, 0);
  });
}
