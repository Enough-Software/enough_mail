import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

import 'imap_loopback_server.dart';

void main() {
  late ImapLoopbackServer server;

  setUp(() async {
    server = await ImapLoopbackServer.start();
  });

  tearDown(() => server.close());

  MailClient client() => MailClient(
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

  test('reconnect() completes when no mailbox was listed yet', () async {
    final mailClient = client();
    await mailClient.connect();
    expect(mailClient.mailboxes, isNull);
    // used to deadlock: reconnect held the incoming lock while the
    // reconnect loop called MailClient.listMailboxes(), which takes it too
    await mailClient.reconnect().timeout(const Duration(seconds: 10));
    expect(mailClient.mailboxes, isNotNull);
    expect(server.connections, 2);
    await mailClient.disconnect();
  });

  test('events are delivered after disconnect and connect', () async {
    final mailClient = client();
    await mailClient.connect();
    await mailClient.selectInbox();
    await mailClient.disconnect();
    await mailClient.connect();
    await mailClient.selectInbox();
    final events = <MailEvent>[];
    mailClient.eventStream.listen(events.add);
    // an IMAP event must still reach the MailClient after a reconnect
    await mailClient.reconnect().timeout(const Duration(seconds: 10));
    // stream events are delivered asynchronously
    await Future.delayed(const Duration(milliseconds: 50));
    expect(events.whereType<MailConnectionReEstablishedEvent>(), isNotEmpty);
    await mailClient.disconnect();
  });
}
