import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';

// cSpell:disable

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

  test('Status of Mailbox with name containing brackets', () {
    const responseText =
        'STATUS "upper level.Funny folder (with brackets)" (MESSAGES 2)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final box = Mailbox(
      encodedName: 'Funny folder (with brackets)',
      encodedPath: 'upper level.Funny folder (with brackets)',
      flags: [MailboxFlag.junk],
      pathSeparator: '.',
    );
    final parser = StatusParser(box);
    final response = Response<Mailbox>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(box.messagesExists, 2);
  });

  test('Status with HIGHESTMODSEQ', () {
    // A CONDSTORE server includes HIGHESTMODSEQ when asked for it (RFC 7162
    // section 3.1.6). It used to fall into the default branch and be printed
    // as unexpected instead of being recorded on the mailbox.
    const responseText =
        'STATUS "INBOX" (MESSAGES 231 UNSEEN 5 HIGHESTMODSEQ 7011231777)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final box = Mailbox(
      encodedName: 'INBOX',
      encodedPath: 'INBOX',
      flags: [MailboxFlag.inbox],
      pathSeparator: '/',
    );
    final parser = StatusParser(box);
    final response = Response<Mailbox>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(box.messagesExists, 231);
    expect(box.messagesUnseen, 5);
    expect(box.highestModSequence, 7011231777);
  });
}
