import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  group('Render', () {
    test('Default', () {
      var param = QResyncParameters(123456789, 987654321);
      expect(param.toString(), 'QRESYNC (123456789 987654321)');
    });

    test('With known UIDs', () {
      var param = QResyncParameters(123456789, 987654321);
      param.knownUids = MessageSequence.fromAll();
      expect(param.toString(), 'QRESYNC (123456789 987654321 1:*)');
    });

    test('With known UIDs and sequence IDs', () {
      var param = QResyncParameters(123456789, 987654321);
      param.knownUids = MessageSequence.fromAll();
      param.setKnownSequenceIdsWithTheirUids(MessageSequence.fromRange(12, 23),
          MessageSequence.fromRange(514, 525));
      expect(param.toString(),
          'QRESYNC (123456789 987654321 1:* (12:23 514:525))');
    });
  });
}
