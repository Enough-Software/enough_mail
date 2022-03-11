import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  group('Render', () {
    test('Default', () {
      final param = QResyncParameters(123456789, 987654321);
      expect(param.toString(), 'QRESYNC (123456789 987654321)');
    });

    test('With known UIDs', () {
      final param = QResyncParameters(123456789, 987654321)
        ..knownUids = MessageSequence.fromAll();
      expect(param.toString(), 'QRESYNC (123456789 987654321 1:*)');
    });

    test('With known UIDs and sequence IDs', () {
      final param = QResyncParameters(123456789, 987654321)
        ..knownUids = MessageSequence.fromAll()
        ..setKnownSequenceIdsWithTheirUids(MessageSequence.fromRange(12, 23),
            MessageSequence.fromRange(514, 525));
      expect(param.toString(),
          'QRESYNC (123456789 987654321 1:* (12:23 514:525))');
    });
  });
}
