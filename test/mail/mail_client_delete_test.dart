import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

import 'imap_loopback_server.dart';

void main() {
  late ImapLoopbackServer server;
  late MailClient mailClient;

  setUp(() async {
    server = await ImapLoopbackServer.start();
    mailClient = MailClient(
      MailAccount.fromManualSettings(
        name: 'test',
        email: 'user@example.com',
        password: 'secret',
        incomingHost: server.host,
        incomingPort: server.port,
        incomingSocketType: SocketType.plainNoStartTls,
        outgoingHost: server.host,
      ),
    );
    await mailClient.connect();
    await mailClient.listMailboxes();
    await mailClient.selectInbox();
    server.requests.clear();
  });

  tearDown(() async {
    await mailClient.disconnect();
    await server.close();
  });

  MimeMessage message() => MimeMessage()
    ..uid = 4711
    ..sequenceId = 1;

  Iterable<String> commands() =>
      server.requests.map((r) => r.substring(r.indexOf(' ') + 1));

  test('deleting a message by UID uses UID STORE and UID EXPUNGE', () async {
    await mailClient.deleteMessage(message(), expunge: true);
    expect(commands(), contains('UID STORE 4711 +FLAGS.SILENT (\\Deleted)'));
    expect(commands(), contains('UID EXPUNGE 4711'));
    expect(commands().where((c) => c.startsWith('STORE ')), isEmpty);
    expect(commands().where((c) => c == 'EXPUNGE'), isEmpty);
  });

  test('moving to trash without MOVE support flags by UID', () async {
    final trash = mailClient.getMailbox(MailboxFlag.trash);
    expect(trash, isNotNull);
    final result = await mailClient.deleteMessage(message());
    expect(result.action, DeleteAction.copy);
    expect(commands(), contains('UID COPY 4711 Trash'));
    expect(commands(), contains('UID STORE 4711 +FLAGS.SILENT (\\Deleted)'));
    expect(commands().where((c) => c.startsWith('STORE ')), isEmpty);
  });

  test('switching mailboxes uses UNSELECT instead of CLOSE', () async {
    final trash = mailClient.getMailbox(MailboxFlag.trash)!;
    await mailClient.selectMailbox(trash);
    expect(commands(), contains('UNSELECT'));
    expect(commands().where((c) => c == 'CLOSE'), isEmpty);
  });
}
