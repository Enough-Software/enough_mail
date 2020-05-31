import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/imap/all_parsers.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:test/test.dart';

void main() {
  test('Status with unseen', () {
    var responseText = 'STATUS "[Gmail]/Spam" (UNSEEN 13)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var box = Mailbox()
      ..name = 'Spam'
      ..path = '[Gmail]/Spam';
    var parser = StatusParser(box);
    var response = Response<Mailbox>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(box.messagesUnseen, 13);
  });

  test('Status with unseen, messages, uidnext, uidvalidity', () {
    var responseText =
        'STATUS "[Gmail]/Spam" (MESSAGES 123 UNSEEN 13 UIDVALIDITY 2222 UIDNEXT 876)';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var box = Mailbox()
      ..name = 'Spam'
      ..path = '[Gmail]/Spam';
    var parser = StatusParser(box);
    var response = Response<Mailbox>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    expect(box.messagesUnseen, 13);
    expect(box.messagesExists, 123);
    expect(box.uidValidity, 2222);
    expect(box.uidNext, 876);
  });
}
