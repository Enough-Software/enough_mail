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
  //await mailExample();
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
      // for (var server in provider.incomingServers) {
      //   print(server);
      // }
      print(provider.preferredIncomingServer);
      print('Outgoing:');
      // for (var server in provider.outgoingServers) {
      //   print(server);
      // }
      print(provider.preferredOutgoingServer);
    }
  }
}

Future<void> mailExample() async {
  var email = userName + '@domain.com';
  var config = await Discover.discover(email);
  var incoming = MailServerConfig()
    ..serverConfig = config.preferredIncomingServer
    ..authentication = PlainAuthentication(userName, password);
  var account = MailAccount()
    ..email = email
    ..incoming = incoming;
  //TODO specify outgoing server configuration
  var mailClient = MailClient(account, isLogEnabled: false);
  await mailClient.connect();
  var mailboxesResponse =
      await mailClient.listMailboxesAsTree(createIntermediate: false);
  if (mailboxesResponse.isOkStatus) {
    print(mailboxesResponse.result);
    await mailClient.selectInbox();
    var fetchResponse = await mailClient.fetchMessages(count: 20);
    if (fetchResponse.isOkStatus) {
      for (var msg in fetchResponse.result) {
        printMessage(msg);
      }
    }
  }
  mailClient.eventBus.on<MailLoadEvent>().listen((event) {
    print('New message at ${DateTime.now()}:');
    printMessage(event.message);
  });
  mailClient.startPolling();
  // print('flat:');
  // var mailboxesFlatResponse = await mailClient.listMailboxes();
  // if (mailboxesFlatResponse.isSuccess) {
  //   print(mailboxesFlatResponse.result);
  // }
}

Future<void> imapExample() async {
  var client = ImapClient(isLogEnabled: false);
  await client.connectToServer(imapServerHost, imapServerPort,
      isSecure: isImapServerSecure);
  var loginResponse = await client.login(userName, password);
  if (loginResponse.isOkStatus) {
    var listResponse = await client.listMailboxes();
    if (listResponse.isOkStatus) {
      print('mailboxes: ${listResponse.result}');
    }
    var inboxResponse = await client.selectInbox();
    if (inboxResponse.isOkStatus) {
      // fetch 10 most recent messages:
      var fetchResponse = await client.fetchRecentMessages(
          messageCount: 10, criteria: 'BODY.PEEK[]');
      if (fetchResponse.isOkStatus) {
        var messages = fetchResponse.result.messages;
        for (var message in messages) {
          printMessage(message);
        }
      }
    }
    await client.logout();
  }
}

Future<void> smtpExample() async {
  var client = SmtpClient('enough.de', isLogEnabled: true);
  await client.connectToServer(smtpServerHost, smtpServerPort,
      isSecure: isSmtpServerSecure);
  var ehloResponse = await client.ehlo();
  if (!ehloResponse.isOkStatus) {
    print('SMTP: unable to say helo/ehlo: ${ehloResponse.message}');
    return;
  }
  var loginResponse = await client.login('user.name', 'password');
  if (loginResponse.isOkStatus) {
    var builder = MessageBuilder.prepareMultipartAlternativeMessage();
    builder.from = [MailAddress('My name', 'sender@domain.com')];
    builder.to = [MailAddress('Your name', 'recipient@domain.com')];
    builder.subject = 'My first message';
    builder.addTextPlain('hello world.');
    builder.addTextHtml('<p>hello <b>world</b></p>');
    var mimeMessage = builder.buildMimeMessage();
    var sendResponse = await client.sendMessage(mimeMessage);
    print('message sent: ${sendResponse.isOkStatus}');
  }
}

Future<void> popExample() async {
  var client = PopClient(isLogEnabled: false);
  await client.connectToServer(popServerHost, popServerPort,
      isSecure: isPopServerSecure);
  var loginResponse = await client.login(userName, password);
  //var loginResponse = await client.loginWithApop(userName, password); // optional different login mechanism
  if (loginResponse.isOkStatus) {
    var statusResponse = await client.status();
    if (statusResponse.isOkStatus) {
      print(
          'status: messages count=${statusResponse.result.numberOfMessages}, messages size=${statusResponse.result.totalSizeInBytes}');
      var listResponse =
          await client.list(statusResponse.result.numberOfMessages);
      print(
          'last message: id=${listResponse.result?.first?.id} size=${listResponse.result?.first?.sizeInBytes}');
      var retrieveResponse =
          await client.retrieve(statusResponse.result.numberOfMessages);
      if (retrieveResponse.isOkStatus) {
        printMessage(retrieveResponse.result);
      } else {
        print('last message could not be retrieved');
      }
      retrieveResponse =
          await client.retrieve(statusResponse.result.numberOfMessages + 1);
      print(
          'trying to retrieve newer message succeeded: ${retrieveResponse.isOkStatus}');
    }
  }
  await client.quit();
}

void printMessage(MimeMessage message) {
  print('from: ${message.from} with subject "${message.decodeSubject()}"');
  if (!message.isTextPlainMessage()) {
    print(' content-type: ${message.mediaType}');
  } else {
    var plainText = message.decodeTextPlainPart();
    if (plainText != null) {
      var lines = plainText.split('\r\n');
      for (var line in lines) {
        if (line.startsWith('>')) {
          // break when quoted text starts
          break;
        }
        print(line);
      }
    }
  }
}
