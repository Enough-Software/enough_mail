An experimental IMAP and SMTP client for Dart developers.

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
  enough_mail: ^0.0.5
```
The latest version or `enough_mail` is [![enough_mail version](https://img.shields.io/pub/v/enough_mail.svg)](https://pub.dartlang.org/packages/enough_mail).


## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

Want to contribute? Please check out [contribute](https://github.com/Enough-Software/enough_mail/contribute).

[tracker]: https://github.com/Enough-Software/enough_mail/issues

### Done
* ✅ basic [IMAP4 rev1](https://tools.ietf.org/html/rfc3501) support 
* ✅ [IMAP IDLE](https://tools.ietf.org/html/rfc2177) support
* ✅ [IMAP METADATA](https://tools.ietf.org/html/rfc5464) support
* ✅ basic [SMTP](https://tools.ietf.org/html/rfc5321) support

### Supported encodings
Character encodings:
* ASCII (7bit)
* UTF-8 (uft8, 8bit)
* ISO-8859-1 (latin-1)

Transfer encodings:
* [Quoted-Printable (Q)](https://tools.ietf.org/html/rfc2045#section-6.7)
* [Base-64 (base64)](https://tools.ietf.org/html/rfc2045#section-6.8)

### To do
* Compare [issues](https://github.com/Enough-Software/enough_mail/issues)
* hardening & bugfixing
* support more encodings
* improve performance
* support [OAuth 2.0](https://tools.ietf.org/html/rfc6749) for login
* support [IMAP4 rev1](https://tools.ietf.org/html/rfc3501) fully
* support [WebPush IMAP Extension](https://github.com/coi-dev/coi-specs/blob/master/webpush-spec.md)
* support [Open PGP](https://tools.ietf.org/html/rfc4880)
* support [POP3](https://tools.ietf.org/html/rfc1939)
* support MIME Pasing
  * [MIME Part One: Format of Internet Message Bodies](https://tools.ietf.org/html/rfc2045)
  * [MIME Part Two: Media Types](https://tools.ietf.org/html/rfc2046)
  * [MIME Part Three: Message Header Extensions for Non-ASCII Text](https://tools.ietf.org/html/rfc2047)

