IMAP, POP3 and SMTP clients for Dart and Flutter email developers.

Available under the commercial friendly 
[MPL Mozilla Public License 2.0](https://www.mozilla.org/en-US/MPL/).


## Installation
Add this dependency your pubspec.yaml file:

```
dependencies:
  enough_mail: ^2.1.1
```
The latest version or `enough_mail` is [![enough_mail version](https://img.shields.io/pub/v/enough_mail.svg)](https://pub.dartlang.org/packages/enough_mail).


## API Documentation
Check out the full API documentation at https://pub.dev/documentation/enough_mail/latest/

## High Level API Usage

The high level API abstracts away from IMAP and POP3 details, reconnects automatically and allows to easily watch a mailbox for new messages.
A simple usage example for using the high level API:

```dart
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';

String userName = 'user.name';
String password = 'password';

void main() async {
  await mailExample();
}


/// Builds a simple example message
MimeMessage buildMessage() {
  final builder = MessageBuilder.prepareMultipartAlternativeMessage(
    plainText: 'Hello world!',
    htmlText: '<p>Hello world!</p>',
  )
    ..from = [MailAddress('Personal Name', 'sender@domain.com')]
    ..to = [
      MailAddress('Recipient Personal Name', 'recipient@domain.com'),
      MailAddress('Other Recipient', 'other@domain.com')
    ];
  return builder.buildMimeMessage();
}

/// Builds an example message with attachment
Future<MimeMessage> buildMessageWithAttachment() async {
  final builder = MessageBuilder()
    ..from = [MailAddress('Personal Name', 'sender@domain.com')]
    ..to = [
      MailAddress('Recipient Personal Name', 'recipient@domain.com'),
      MailAddress('Other Recipient', 'other@domain.com')
    ]
    ..addMultipartAlternative(
      plainText: 'Hello world!',
      htmlText: '<p>Hello world!</p>',
    );
  final file = File.fromUri(Uri.parse('file://./document.pdf'));
  await builder.addFile(file, MediaSubtype.applicationPdf.mediaType);
  return builder.buildMimeMessage();
}

/// High level mail API example
Future<void> mailExample() async {
  final email = '$userName@$domain';
  print('discovering settings for  $email...');
  final config = await Discover.discover(email);
  if (config == null) {
    // note that you can also directly create an account when
    // you cannot auto-discover the settings:
    // Compare the [MailAccount.fromManualSettings]
    // and [MailAccount.fromManualSettingsWithAuth]
    // methods for details.
    print('Unable to auto-discover settings for $email');
    return;
  }
  print('connecting to ${config.displayName}.');
  final account =
      MailAccount.fromDiscoveredSettings('my account', email, password, config);
  final mailClient = MailClient(account, isLogEnabled: true);
  try {
    await mailClient.connect();
    print('connected');
    final mailboxes =
        await mailClient.listMailboxesAsTree(createIntermediate: false);
    print(mailboxes);
    await mailClient.selectInbox();
    final messages = await mailClient.fetchMessages(count: 20);
    messages.forEach(printMessage);
    mailClient.eventBus.on<MailLoadEvent>().listen((event) {
      print('New message at ${DateTime.now()}:');
      printMessage(event.message);
    });
    await mailClient.startPolling();
    // generate and send email:
    final mimeMessage = buildMessage();
    await mailClient.sendMessage(mimeMessage);
  } on MailException catch (e) {
    print('High level API failed with $e');
  }
}
```

## Low Level Usage

A simple usage example for using the low level API:

```dart
import 'dart:io';
import 'package:enough_mail/enough_mail.dart';

String userName = 'user.name';
String password = 'password';
String imapServerHost = 'imap.domain.com';
int imapServerPort = 993;
bool isImapServerSecure = true;
String popServerHost = 'pop.domain.com';
int popServerPort = 995;
bool isPopServerSecure = true;
String smtpServerHost = 'smtp.domain.com';
int smtpServerPort = 465;
bool isSmtpServerSecure = true;

void main() async {
  await discoverExample();
  await imapExample();
  await smtpExample();
  await popExample();
  exit(0);
}

Future<void> discoverExample() async {
  var email = 'someone@enough.de';
  var config = await Discover.discover(email, isLogEnabled: false);
  if (config == null) {
    print('Unable to discover settings for $email');
  } else {
    print('Settings for $email:');
    for (var provider in config.emailProviders) {
      print('provider: ${provider.displayName}');
      print('provider-domains: ${provider.domains}');
      print('documentation-url: ${provider.documentationUrl}');
      print('Incoming:');
      print(provider.preferredIncomingServer);
      print('Outgoing:');
      print(provider.preferredOutgoingServer);
    }
  }
}

/// Low level IMAP API usage example
Future<void> imapExample() async {
  final client = ImapClient(isLogEnabled: false);
  try {
    await client.connectToServer(imapServerHost, imapServerPort,
        isSecure: isImapServerSecure);
    await client.login(userName, password);
    final mailboxes = await client.listMailboxes();
    print('mailboxes: $mailboxes');
    await client.selectInbox();
    // fetch 10 most recent messages:
    final fetchResult = await client.fetchRecentMessages(
        messageCount: 10, criteria: 'BODY.PEEK[]');
    for (final message in fetchResult.messages) {
      printMessage(message);
    }
    await client.logout();
  } on ImapException catch (e) {
    print('IMAP failed with $e');
  }
}

/// Low level SMTP API example
Future<void> smtpExample() async {
  final client = SmtpClient('enough.de', isLogEnabled: true);
  try {
    await client.connectToServer(smtpServerHost, smtpServerPort,
        isSecure: isSmtpServerSecure);
    await client.ehlo();
    if (client.serverInfo.supportsAuth(AuthMechanism.plain)) {
      await client.authenticate('user.name', 'password', AuthMechanism.plain);
    } else if (client.serverInfo.supportsAuth(AuthMechanism.login)) {
      await client.authenticate('user.name', 'password', AuthMechanism.login);
    } else {
      return;
    }
    final builder = MessageBuilder.prepareMultipartAlternativeMessage(
      plainText: 'hello world.',
      htmlText: '<p>hello <b>world</b></p>',
    )
      ..from = [MailAddress('My name', 'sender@domain.com')]
      ..to = [MailAddress('Your name', 'recipient@domain.com')]
      ..subject = 'My first message';
    final mimeMessage = builder.buildMimeMessage();
    final sendResponse = await client.sendMessage(mimeMessage);
    print('message sent: ${sendResponse.isOkStatus}');
  } on SmtpException catch (e) {
    print('SMTP failed with $e');
  }
}

/// Low level POP3 API example
Future<void> popExample() async {
  final client = PopClient(isLogEnabled: false);
  try {
    await client.connectToServer(popServerHost, popServerPort,
        isSecure: isPopServerSecure);
    await client.login(userName, password);
    // alternative login:
    // await client.loginWithApop(userName, password); // optional different login mechanism
    final status = await client.status();
    print(
        'status: messages count=${status.numberOfMessages}, messages size=${status.totalSizeInBytes}');
    final messageList = await client.list(status.numberOfMessages);
    print(
        'last message: id=${messageList?.first?.id} size=${messageList?.first?.sizeInBytes}');
    var message = await client.retrieve(status.numberOfMessages);
    printMessage(message);
    message = await client.retrieve(status.numberOfMessages + 1);
    print('trying to retrieve newer message succeeded');
    await client.quit();
  } on PopException catch (e) {
    print('POP failed with $e');
  }
}

void printMessage(MimeMessage message) {
  print('from: ${message.from} with subject "${message.decodeSubject()}"');
  if (!message.isTextPlainMessage()) {
    print(' content-type: ${message.mediaType}');
  } else {
    final plainText = message.decodeTextPlainPart();
    if (plainText != null) {
      final lines = plainText.split('\r\n');
      for (final line in lines) {
        if (line.startsWith('>')) {
          // break when quoted text starts
          break;
        }
        print(line);
      }
    }
  }
}
```

## Related Projects
Check out these related projects:
* [enough_mail_html](https://github.com/Enough-Software/enough_mail_html) generates HTML out of a `MimeMessage`.
* [enough_mail_flutter](https://github.com/Enough-Software/enough_mail_flutter) provides some common Flutter widgets for any mail app.
* [enough_mail_icalendar](https://github.com/Enough-Software/enough_mail_icalendar) for handling calendar invites in emails.
* [enough_mail_app](https://github.com/Enough-Software/enough_mail_app) aims to become a full mail app.
* [enough_convert](https://github.com/Enough-Software/enough_convert) provides the encodings missing from `dart:convert`.  

## Miss a feature or found a bug?

Please file feature requests and bugs at the [issue tracker](https://github.com/Enough-Software/enough_mail/issues).

## Contribute

Want to contribute? Please check out [contribute](https://github.com/Enough-Software/enough_mail/contribute).
This is an open-source community project. Anyone, even beginners, can contribute.

This is how you contribute:

* Fork the [enough_mail](https://github.com/enough-software/enough_mail/) project by pressing the fork button.
* Clone your fork to your computer: `git clone github.com/$your_username/enough_mail`
* Do your changes. When you are done, commit changes with `git add -A` and `git commit`.
* Push changes to your personal repository: `git push origin`
* Go to [enough_mail](https://github.com/enough-software/enough_mail/)  and create a pull request.

Thank you in advance!

## Features
### Base standards
* ✅ [IMAP4 rev1](https://tools.ietf.org/html/rfc3501) support 
* ✅ [SMTP](https://tools.ietf.org/html/rfc5321) support
* ✅ [POP3](https://tools.ietf.org/html/rfc1939) support
* ✅ [MIME](https://tools.ietf.org/html/rfc2045) parsing and generation support

### IMAP extensions
The following IMAP extensions are supported:
* ✅ [IMAP IDLE](https://tools.ietf.org/html/rfc2177)
* ✅ [IMAP METADATA](https://tools.ietf.org/html/rfc5464)
* ✅ [UIDPLUS](https://tools.ietf.org/html/rfc2359) 
* ✅ [MOVE](https://tools.ietf.org/html/rfc6851) 
* ✅ [CONDSTORE](https://tools.ietf.org/html/rfc7162) 
* ✅ [QRESYNC](https://tools.ietf.org/html/rfc7162) 
* ✅ [ENABLE](https://tools.ietf.org/html/rfc5161)
* ✅ [QUOTA](https://tools.ietf.org/html/rfc2087)
* ✅ [IMAP Support for UTF-8](https://tools.ietf.org/html/rfc6855) 
* ✅ [ESEARCH](https://tools.ietf.org/html/rfc4731)
* ✅ [SORT and THREAD](https://tools.ietf.org/html/rfc5256)
* ✅ [UNSELECT](https://tools.ietf.org/html/rfc3691))
* ✅ ESORT and PARTIAL from [Contexts](https://tools.ietf.org/html/rfc5267)
* ✅ List extensions ([rfc5258](https://tools.ietf.org/html/rfc5258), [rfc5819](https://tools.ietf.org/html/rfc5819), [rfc6154](https://tools.ietf.org/html/rfc6154))

### SMTP Extensions
The following SMTP extensions are supported:
* ✅ [8-bit MIME](https://tools.ietf.org/html/rfc6152)

### Security
The following security extensions are supported:
* ✅ Partial signing of messages using [DKIM](https://tools.ietf.org/html/rfc6376)
 

### Supported encodings
Character encodings:
* ASCII (7bit)
* UTF-8 (uft8, 8bit)
* ISO-8859-1 (latin-1)
* ISO-8859-2 - 16 (latin-2 - 16)
* Windows-1250, 1251, 1252, 1253, 1254 and 1256
* GB-2312, GBK, GB-18030, Chinese, CSGB-2312, CSGB-231280, CSISO-58-GB-231280, ISO-IR-58, X-Mac-ChineseSimp
* Big5
* KOI8-r and KOI8-u

Transfer encodings:
* [Quoted-Printable (Q)](https://tools.ietf.org/html/rfc2045#section-6.7)
* [Base-64 (base64)](https://tools.ietf.org/html/rfc2045#section-6.8)

### To do
* Compare [issues](https://github.com/Enough-Software/enough_mail/issues)

### Develop and Contribute
* To start check out the package and then run `dart run test` to run all tests.
* Public facing library classes are in *lib*, *lib/imap* and *lib/smtp*. 
* Private classes are in *lib/src*.
* Test cases are in *test*.
* Please file a pull request for each improvement/fix that you are create - your contributions are welcome.
* Check out https://github.com/enough-Software/enough_mail/contribute for good first issues.

## License
`enough_mail` is licensed under the commecial friendly [Mozilla Public License 2.0](LICENSE).