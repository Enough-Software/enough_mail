import 'package:enough_mail/src/imap/mailbox.dart';
import 'package:test/test.dart';

void main() {
  test('virtual mailbox', () {
    final mailbox = Mailbox.virtual('All Inboxes', [MailboxFlag.inbox]);
    expect(mailbox.isInbox, true);
    expect(mailbox.isVirtual, true);
    expect(mailbox.name, 'All Inboxes');
    expect(mailbox.flags, [MailboxFlag.inbox, MailboxFlag.virtual]);
  });

  test('virtual mailbox to not have virtual flags duplicated', () {
    final mailbox = Mailbox.virtual(
        'All Inboxes', [MailboxFlag.inbox, MailboxFlag.virtual]);
    expect(mailbox.isInbox, true);
    expect(mailbox.isVirtual, true);
    expect(mailbox.name, 'All Inboxes');
    expect(mailbox.flags, [MailboxFlag.inbox, MailboxFlag.virtual]);
  });

  test('encode simple path', () {
    const original = 'Inbox/Archive';
    expect(Mailbox.encode(original, '/'), original);
  });
  test('encode path with special characters', () {
    const original = 'Inbox/Müllhalde';
    expect(Mailbox.encode(original, '/'), 'Inbox/M&APw-llhalde');
  });

  test('reset name', () {
    final mailbox = Mailbox(
        encodedName: 'Inbox',
        encodedPath: 'root/Inbox',
        flags: [MailboxFlag.inbox],
        pathSeparator: '/')
      ..name = 'Posteingang';
    expect(mailbox.name, 'Posteingang');
    expect(mailbox.encodedName, 'Inbox');
    expect(mailbox.encodedPath, 'root/Inbox');
    expect(mailbox.path, 'root/Inbox');
    mailbox.setNameFromPath();
    expect(mailbox.name, 'Inbox');
  });
}
