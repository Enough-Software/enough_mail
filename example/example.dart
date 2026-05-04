import 'package:enough_mail/enough_mail.dart';

/// Simple example demonstrating basic email discovery and IMAP usage.
void main() async {
  // Auto-discover email settings
  const email = 'user@example.com';
  final config = await Discover.discover(email, isLogEnabled: false);

  if (config == null) {
    print('Unable to discover settings for $email');
    return;
  }

  print('Found settings for $email:');
  for (final provider in config.emailProviders ?? []) {
    print('Provider: ${provider.displayName}');
    print('Domains: ${provider.domains}');
  }

  // IMAP example
  final imapClient = ImapClient(isLogEnabled: false);
  await imapClient.connectToServer('imap.example.com', 993, isSecure: true);
  await imapClient.login('user@example.com', 'password');
  await imapClient.selectInbox();

  final messages = await imapClient.fetchRecentMessages(messageCount: 5);
  for (final message in messages.messages) {
    print('From: ${message.from}');
    print('Subject: ${message.decodeSubject()}');
  }

  await imapClient.logout();

  // SMTP example
  final smtpClient = SmtpClient('example.com', isLogEnabled: false);
  await smtpClient.connectToServer('smtp.example.com', 587, isSecure: false);
  await smtpClient.ehlo();
  if (smtpClient.serverInfo.supportsAuth(AuthMechanism.plain)) {
    await smtpClient.authenticate(
      'user@example.com',
      'password',
      AuthMechanism.plain,
    );
  }

  final builder = MessageBuilder()
    ..from = [const MailAddress('Sender', 'sender@example.com')]
    ..to = [const MailAddress('Recipient', 'recipient@example.com')]
    ..subject = 'Test Email'
    ..text = 'Hello from enough_mail!';

  final message = builder.buildMimeMessage();
  await smtpClient.sendMessage(message);
  print('Email sent successfully!');
}
