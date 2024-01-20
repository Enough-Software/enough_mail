import 'package:enough_mail/src/codecs/mail_codec.dart';
import 'package:enough_mail/src/mail_address.dart';
import 'package:enough_mail/src/message_builder.dart';
import 'package:enough_mail/src/mime_message.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  test('folding test qp-encode full', () {
    const subject = 'àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ àáèéìíòóùúỳýäëïöü'
        'ÿæßñµ¢łŁasciiàáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ';
    final message = _buildTestMessage(subject);
    expect(message?.decodeSubject(), subject);
    final buffer = StringBuffer();
    message?.getHeader('subject')?.first.render(buffer);
    final output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(_HasLength(lessThanOrEqualTo(76))));
  });

  test('folding test qp-encode greek', () {
    const subject = 'Λορεμ ιπσθμ δολορ σιτ αμετ, φερρι φαβθλασ οπορτεατ σεα ει';
    final message = _buildTestMessage(subject);
    expect(message?.decodeSubject(), subject);
    final buffer = StringBuffer();
    message?.getHeader('subject')?.first.render(buffer);
    final output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(_HasLength(lessThanOrEqualTo(76))));
  });

  test('folding test mixed qp-encode', () {
    const subject = 'Quick: do you have a plan to become proactive '
        'àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ. '
        'We understand that if you integrate intuitively then you may also '
        'mesh iteravely.';
    final message = _buildTestMessage(subject);
    expect(message?.decodeSubject(), subject);
    final buffer = StringBuffer();
    message?.getHeader('subject')?.first.render(buffer);
    final output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(_HasLength(lessThanOrEqualTo(76))));
  });

  test('folding test b-encode', () {
    const subject = 'Quick: do you have a plan to become proactive '
        'àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ. '
        'We understand that if you integrate intuitively then you may also '
        'mesh iteravely.';
    final message = _buildTestMessage(subject, HeaderEncoding.B);
    expect(message?.decodeSubject(), subject);
    final buffer = StringBuffer();
    message?.getHeader('subject')?.first.render(buffer);
    final output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(_HasLength(lessThanOrEqualTo(76))));
  });
}

MimeMessage? _buildTestMessage(
  String subject, [
  HeaderEncoding encoding = HeaderEncoding.Q,
]) =>
    MessageBuilder.buildSimpleTextMessage(
      const MailAddress('mittente', 'test@example.com'),
      [const MailAddress('destinatario', 'recipient@example.com')],
      'This is a short text',
      subject: subject,
      subjectEncoding: encoding,
    );

class _HasLength extends CustomMatcher {
  _HasLength(matcher) : super('String which length than is', 'length', matcher);
  @override
  int featureValueOf(dynamic actual) => (actual as String).length;
}
