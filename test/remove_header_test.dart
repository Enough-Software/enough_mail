import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  test('bcc cleanup', () {
    final builder = MessageBuilder.prepareMultipartAlternativeMessage(
      plainText: 'Hello world!',
      htmlText: '<p>Hello world!</p>',
    )..bcc = [const MailAddress(null, 'bcc@domain.com')];

    final message = builder.buildMimeMessage();
    final rawContent = message.renderMessage();

    final tempMessage = MimeMessage.parseFromText(rawContent)
      ..removeHeader('bcc');

    expect(
      tempMessage.renderMessage().contains('Bcc: bcc@domain.com'),
      isFalse,
    );
  });
}
