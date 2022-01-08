import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';

void main() {
  test('Status with unseen', () {
    const responseText = 'STATUS "[Gmail]/Spam" (UNSEEN 13)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final box = Mailbox(
      encodedName: 'Spam',
      encodedPath: '[Gmail]/Spam',
      flags: [MailboxFlag.junk],
      pathSeparator: '/',
    );
    final parser = StatusParser(box);
    final response = Response<Mailbox>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(box.messagesUnseen, 13);
  });

  test('Status with unseen, messages, uidnext, uidvalidity', () {
    const responseText =
        'STATUS "[Gmail]/Spam" (MESSAGES 123 UNSEEN 13 UIDVALIDITY 2222 UIDNEXT 876)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final box = Mailbox(
      encodedName: 'Spam',
      encodedPath: '[Gmail]/Spam',
      flags: [MailboxFlag.junk],
      pathSeparator: '/',
    );
    final parser = StatusParser(box);
    final response = Response<Mailbox>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(box.messagesUnseen, 13);
    expect(box.messagesExists, 123);
    expect(box.uidValidity, 2222);
    expect(box.uidNext, 876);
  });
}
