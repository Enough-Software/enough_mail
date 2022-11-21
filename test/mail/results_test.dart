import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  group('DeleteResult', () {
    late List<MimeMessage> messages;
    late DeleteResult deleteResult;

    setUp(() {
      messages = [
        MimeMessage()
          ..sequenceId = 12
          ..uid = 120,
        MimeMessage()
          ..sequenceId = 13
          ..uid = 121
      ];
      final originalSequence = messages.toSequence();
      final originalMailbox = Mailbox.virtual('inbox', [MailboxFlag.inbox]);
      final targetSequence = MessageSequence.fromIds([400, 401], isUid: true);
      final targetMailbox = Mailbox.virtual('trash', [MailboxFlag.trash]);
      final mailClient = MailClient(
        MailAccount.fromManualSettings(
          name: 'name',
          userName: 'userName',
          email: 'email',
          incomingHost: 'incomingHost',
          outgoingHost: 'outgoingHost',
          password: 'password',
        ),
      );
      deleteResult = DeleteResult(
        DeleteAction.move,
        originalSequence,
        originalMailbox,
        targetSequence,
        targetMailbox,
        mailClient,
        canUndo: true,
        messages: messages,
      );
    });

    test('DeleteResult changes the message UID', () {
      expect(messages[0].uid, 400);
      expect(messages[1].uid, 401);
    });

    test('Undo DeleteResult changes the message UID again', () {
      expect(messages[0].uid, 400);
      expect(messages[1].uid, 401);
      final result = GenericImapResult()
        ..responseCode = 'COPYUID 14 400,401 17,18';
      final copyUid = result.responseCodeCopyUid;
      expect(copyUid, isNotNull);
      expect(
        copyUid?.originalSequence?.toList(),
        [400, 401],
      );
      expect(
        copyUid?.targetSequence.toList(),
        [17, 18],
      );
      final undoResult = deleteResult.reverseWith(copyUid);
      expect(
        undoResult.targetMailbox?.flags,
        [MailboxFlag.inbox, MailboxFlag.virtual],
      );
      expect(undoResult.originalSequence.toList(), [400, 401]);
      expect(undoResult.targetSequence?.toList(), [17, 18]);
      expect(messages[0].uid, 17);
      expect(messages[1].uid, 18);
    });
  });
}
