import 'package:enough_mail/src/codecs/mail_codec.dart';
import 'package:enough_mail/src/mail_address.dart';
import 'package:enough_mail/src/message_builder.dart';
import 'package:enough_mail/src/mime_message.dart';
import 'package:test/test.dart';

void main() {
  test('folding test qp-encode full', () {
    final subject =
        'àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁasciiàáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ';
    var message = _buildTestMessage(subject);
    expect(message!.decodeSubject(), subject);
    var buffer = StringBuffer();
    message.getHeader('subject')!.first.render(buffer);
    var output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(HasLength(lessThanOrEqualTo(76))));
  });

  test('folding test qp-encode greek', () {
    final subject = 'Λορεμ ιπσθμ δολορ σιτ αμετ, φερρι φαβθλασ οπορτεατ σεα ει';
    var message = _buildTestMessage(subject);
    expect(message!.decodeSubject(), subject);
    var buffer = StringBuffer();
    message.getHeader('subject')!.first.render(buffer);
    var output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(HasLength(lessThanOrEqualTo(76))));
  });

  test('folding test mixed qp-encode', () {
    final subject =
        'Quick: do you have a plan to become proactive àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ. '
        'We understand that if you integrate intuitively then you may also mesh iteravely.';
    var message = _buildTestMessage(subject);
    expect(message!.decodeSubject(), subject);
    var buffer = StringBuffer();
    message.getHeader('subject')!.first.render(buffer);
    var output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(HasLength(lessThanOrEqualTo(76))));
  });

  test('folding test b-encode', () {
    final subject =
        'Quick: do you have a plan to become proactive àáèéìíòóùúỳýäëïöüÿæßñµ¢łŁ. '
        'We understand that if you integrate intuitively then you may also mesh iteravely.';
    var message = _buildTestMessage(subject, HeaderEncoding.B);
    expect(message!.decodeSubject(), subject);
    var buffer = StringBuffer();
    message.getHeader('subject')!.first.render(buffer);
    var output = buffer.toString().split(RegExp(r'\r\n\s+'));
    expect(output.length, greaterThan(1));
    expect(output, everyElement(HasLength(lessThanOrEqualTo(76))));
  });
}

MimeMessage? _buildTestMessage(String subject,
        [HeaderEncoding encoding = HeaderEncoding.Q]) =>
    MessageBuilder.buildSimpleTextMessage(
      MailAddress('mittente', 'test@example.com'),
      [MailAddress('destinatario', 'recipient@example.com')],
      'This is a short text',
      subject: subject,
      subjectEncoding: encoding,
    );

class HasLength extends CustomMatcher {
  HasLength(matcher) : super('String which length than is', 'length', matcher);
  @override
  int featureValueOf(actual) => (actual as String).length;
}
