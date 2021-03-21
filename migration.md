## Migrating

If you have been using a 0.0.x version of the API you need to switch from evaluating responses to just getting the data and handling exceptions if something went wrong.

Old code example:
```dart
final client = ImapClient(isLogEnabled: false);
await client.connectToServer(imapServerHost, imapServerPort,
    isSecure: isImapServerSecure);
final loginResponse = await client.login(userName, password);
if (loginResponse.isOkStatus) {
  final listResponse = await client.listMailboxes();
  if (listResponse.isOkStatus) {
    print('mailboxes: ${listResponse.result}');
    final inboxResponse = await client.selectInbox();
    if (inboxResponse.isOkStatus) {
      // fetch 10 most recent messages:
      final fetchResponse = await client.fetchRecentMessages(
          messageCount: 10, criteria: 'BODY.PEEK[]');
      if (fetchResponse.isOkStatus) {
        final messages = fetchResponse.result.messages;
        for (var message in messages) {
          printMessage(message);
        }
      }
    }
  }
  await client.logout();
}
```

Migrated code example:
```dart
final client = ImapClient(isLogEnabled: false);
try {
  await client.connectToServer(imapServerHost, imapServerPort,
    isSecure: isImapServerSecure);
  await client.login(userName, password);
  final mailboxes = await client.listMailboxes();
  print('mailboxes: ${mailboxes}');
  await client.selectInbox();
  // fetch 10 most recent messages:
  final fetchResult = await client.fetchRecentMessages(
      messageCount: 10, criteria: 'BODY.PEEK[]');
  for (var message in fetchResult.messages) {
    printMessage(message);
  }
  await client.logout();
} on ImapException catch (e) {
  print('imap failed with $e');
}
```

As you can see the code is now much simpler and shorter.

Depending on which API you use there are different exceptions to handle:
* `MailException` for the high level API
* `ImapException` for the low level IMAP API
* `PopException` for the low level POP3 API
* `SmtpException` for the low level SMTP API
