import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  group('GenericImapResult', () {
    test('Valid COPYUID with original and target single IDs', () {
      final result = GenericImapResult()
        ..responseCode = 'COPYUID 14 35986 172551';
      final copyUid = result.responseCodeCopyUid;
      expect(copyUid, isNotNull);
      expect(copyUid!.uidValidity, 14);
      expect(copyUid.originalSequence?.toList(), [35986]);
      expect(copyUid.targetSequence.toList(), [172551]);
    });

    test('Valid COPYUID with original and target sequence', () {
      final result = GenericImapResult()
        ..responseCode = 'COPYUID 14 35986:35989 172551:172554';
      final copyUid = result.responseCodeCopyUid;
      expect(copyUid, isNotNull);
      expect(copyUid!.uidValidity, 14);
      expect(copyUid.originalSequence?.toList(), [35986, 35987, 35988, 35989]);
      expect(copyUid.targetSequence.toList(), [172551, 172552, 172553, 172554]);
    });

    test('Igmore invalid COPYUID withhout sequences', () {
      final result = GenericImapResult()..responseCode = 'COPYUID 12  ';
      final copyUid = result.responseCodeCopyUid;
      expect(copyUid, isNull);
    });
  });
}
