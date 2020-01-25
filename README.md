An experiments IMAP and SMTP client for Dart developers.

Available under the commercial friendly 
[MPL Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/).

## Usage

A simple usage example:

```dart
import 'package:enough_mail/enough_mail.dart';

main() async {
  var client  = ImapClient(isLogEnabled: true);
  await client.connectToServer('imap.example.com', 993, isSecure: true);
  var loginResponse = await client.login('user.name', 'secret');
  if (loginResponse.isOkStatus) {
    var listResponse = await client.listMailboxes();
    if (listResponse.isOkStatus) {
      print('mailboxes: ${listResponse.result}');
    }
  }
}
```

## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_mail: ^0.0.1
```

For more info visit [pub.dev](https://pub.dev/packages/enough_mail).

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Enough-Software/enough_mail/issues
