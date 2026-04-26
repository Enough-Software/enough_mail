import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  test('Should not fold long email address in From header', () {
    const longEmail =
        'npub1mlfgj95gv89tdjemt2jc4jqvn4dumhujeymzv20ljqywcfupwz5s09pe55@testnm'
        'ail.uid.ovh';

    final builder = MessageBuilder()
      ..from = [const MailAddress('Test', longEmail)];
    final mimeMessage = builder.buildMimeMessage();
    final rendered = mimeMessage.renderMessage();

    expect(rendered, contains('<$longEmail>'));
  });
}
