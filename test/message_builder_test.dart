import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/src/mail_address.dart';
import 'package:enough_mail/src/mail_conventions.dart';
import 'package:enough_mail/src/media_type.dart';
import 'package:enough_mail/src/message_builder.dart';
import 'package:enough_mail/src/mime_data.dart';
import 'package:enough_mail/src/mime_message.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  String? getRawBodyText(MimePart part) {
    final mimeData = part.mimeData;
    if (mimeData is TextMimeData) {
      return mimeData.body;
    }
    return null;
  }

  group('buildSimpleTextMessage', () {
    test('Simple text message', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject);
      //print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');
      expect(
          getRawBodyText(message),
          'Hello World - here\s some text that should spans two lines in the '
          'end when t=\r\nhis sentence is finished.\r\n');
    });

    test('Simple text message with reply to message', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.';
      final replyToMessage = MimeMessage()
        ..addHeader('subject', 'Re: Hello from test')
        ..addHeader('message-id', '<some-unique-sequence@domain.com>');
      final message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          replyToMessage: replyToMessage);
      expect(message.getHeaderValue('subject'), 'Re: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('references'),
          '<some-unique-sequence@domain.com>');
      expect(message.getHeaderValue('in-reply-to'),
          '<some-unique-sequence@domain.com>');
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');
      expect(
          getRawBodyText(message),
          'Hello World - here\s some text that should spans two lines in the '
          'end when t=\r\nhis sentence is finished.');
      //print(message.renderMessage());
    });

    test('Simple chat message', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\'s some text that should spans two lines in the '
          'end when this sentence is finished.';
      final message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject, isChat: true);
      expect(message.getHeaderValue('subject'), 'Hello from test');
      var id = message.getHeaderValue('message-id')!;
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$'), isTrue);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');

      final messageText = message.renderMessage();
      //print(messageText);
      final parsed = MimeMessage.parseFromText(messageText);

      expect(parsed.getHeaderValue('subject'), 'Hello from test');
      id = parsed.getHeaderValue('message-id')!;
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$'), isTrue);
      expect(parsed.getHeaderValue('date'), isNotNull);
      expect(
          parsed.getHeaderValue('from'), '"Personal Name" <sender@domain.com>');
      expect(parsed.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(
          parsed.getHeaderValue('Content-Type'), 'text/plain; charset="utf-8"');
      expect(parsed.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');
      expect(
          parsed.decodeContentText(),
          'Hello World - here\'s some text that should spans two lines in the '
          'end when this sentence is finished.');
    });

    test('Simple chat group message', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com'),
        MailAddress('Other Recipient', 'other@domain.com')
      ];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.';
      final message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject, isChat: true, chatGroupId: '1234abc123');
      expect(message.getHeaderValue('subject'), 'Hello from test');
      var id = message.getHeaderValue('message-id')!;
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$group.1234abc123.'), isTrue);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(
          message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>, '
          '"Other Recipient" <other@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');

      final buffer = StringBuffer();
      message.render(buffer);
      final messageText = buffer.toString();
      //print(messageText);
      final parsed = MimeMessage.parseFromText(messageText);

      expect(parsed.getHeaderValue('subject'), 'Hello from test');
      id = parsed.getHeaderValue('message-id')!;
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$group.1234abc123.'), isTrue);
      expect(parsed.getHeaderValue('date'), isNotNull);
      expect(
          parsed.getHeaderValue('from'), '"Personal Name" <sender@domain.com>');
      final toRecipients = parsed.decodeHeaderMailAddressValue('to')!;
      expect(toRecipients, isNotNull);
      expect(toRecipients.length, 2);
      expect(toRecipients[0].email, 'recipient@domain.com');
      expect(toRecipients[0].hostName, 'domain.com');
      expect(toRecipients[0].mailboxName, 'recipient');
      expect(toRecipients[0].personalName, 'Recipient Personal Name');
      expect(toRecipients[1].email, 'other@domain.com');
      expect(toRecipients[1].hostName, 'domain.com');
      expect(toRecipients[1].mailboxName, 'other');
      expect(toRecipients[1].personalName, 'Other Recipient');
      expect(
          parsed.getHeaderValue('Content-Type'), 'text/plain; charset="utf-8"');
      expect(parsed.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');
      expect(
          parsed.decodeContentText(),
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.');
    });
  });

  group('multipart tests', () {
    test('multipart/alternative with 2 text parts', () {
      final builder = MessageBuilder.prepareMultipartAlternativeMessage()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..addTextPlain('Hello world!')
        ..addTextHtml('<p>Hello world!</p>');
      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      //print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartAlternative);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 2);
      expect(parsed.parts![0].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textHtml);
      expect(parsed.parts![1].decodeContentText(), '<p>Hello world!</p>\r\n');
    });

    test('multipart/mixed with vcard attachment', () {
      final builder = MessageBuilder.prepareMultipartMixedMessage()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..addTextPlain('Hello world!')
        ..addText('''
BEGIN:VCARD\r
VERSION:4.0\r
UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1\r
FN:J. Doe\r
N:Doe;J.;;;\r
EMAIL;PID=1.1:jdoe@example.com\r
EMAIL;PID=2.1:boss@example.com\r
EMAIL;PID=2.2:ceo@example.com\r
TEL;PID=1.1;VALUE=uri:tel:+1-555-555-5555\r
TEL;PID=2.1,2.2;VALUE=uri:tel:+1-666-666-6666\r
CLIENTPIDMAP:1;urn:uuid:53e374d9-337e-4727-8803-a1e9c14e0556\r
CLIENTPIDMAP:2;urn:uuid:1f762d2b-03c4-4a83-9a03-75ff658a6eee\r
END:VCARD\r
''',
            mediaType: MediaSubtype.textVcard.mediaType,
            disposition: ContentDispositionHeader.from(
                ContentDisposition.attachment,
                filename: 'contact.vcard'));

      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      //print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 2);
      expect(parsed.parts![0].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textVcard);
      final disposition = parsed.parts![1].getHeaderContentDisposition()!;
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'contact.vcard');
      expect(parsed.parts![1].decodeContentText(), '''
BEGIN:VCARD\r
VERSION:4.0\r
UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1\r
FN:J. Doe\r
N:Doe;J.;;;\r
EMAIL;PID=1.1:jdoe@example.com\r
EMAIL;PID=2.1:boss@example.com\r
EMAIL;PID=2.2:ceo@example.com\r
TEL;PID=1.1;VALUE=uri:tel:+1-555-555-5555\r
TEL;PID=2.1,2.2;VALUE=uri:tel:+1-666-666-6666\r
CLIENTPIDMAP:1;urn:uuid:53e374d9-337e-4727-8803-a1e9c14e0556\r
CLIENTPIDMAP:2;urn:uuid:1f762d2b-03c4-4a83-9a03-75ff658a6eee\r
END:VCARD\r
\r
''');
    });

    test('implicit multipart with binary attachment', () {
      final builder = MessageBuilder()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..text = 'Hello world!'
        ..addBinary(Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
            MediaSubtype.imageJpeg.mediaType,
            filename: 'helloworld.jpg')
        ..setRecommendedTextEncoding(
          supports8BitMessages: true,
        );
      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      // print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 2);
      expect(parsed.parts![0].getHeaderContentType()?.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()?.mediaType.sub,
          MediaSubtype.imageJpeg);
      expect(parsed.parts![1].getHeaderContentType()?.parameters['name'],
          'helloworld.jpg');
      final disposition = parsed.parts![1].getHeaderContentDisposition();
      expect(disposition, isNotNull);
      expect(disposition!.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'helloworld.jpg');
      expect(disposition.size, 10);
      expect(parsed.parts![1].decodeContentBinary(),
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
    });

    test('implicit multipart with binary attachment and text', () {
      final builder = MessageBuilder()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..addTextPlain('Hello world!')
        ..addText(
          '''
BEGIN:VCARD\r
VERSION:4.0\r
UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1\r
FN:J. Doe\r
N:Doe;J.;;;\r
EMAIL;PID=1.1:jdoe@example.com\r
EMAIL;PID=2.1:boss@example.com\r
EMAIL;PID=2.2:ceo@example.com\r
TEL;PID=1.1;VALUE=uri:tel:+1-555-555-5555\r
TEL;PID=2.1,2.2;VALUE=uri:tel:+1-666-666-6666\r
CLIENTPIDMAP:1;urn:uuid:53e374d9-337e-4727-8803-a1e9c14e0556\r
CLIENTPIDMAP:2;urn:uuid:1f762d2b-03c4-4a83-9a03-75ff658a6eee\r
END:VCARD\r
''',
          mediaType: MediaSubtype.textVcard.mediaType,
          disposition: ContentDispositionHeader.from(
              ContentDisposition.attachment,
              filename: 'contact.vcard'),
        )
        ..addBinary(Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]),
            MediaSubtype.imageJpeg.mediaType,
            filename: 'helloworld.jpg');

      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      //print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 3);
      expect(parsed.parts![0].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textVcard);
      var disposition = parsed.parts![1].getHeaderContentDisposition()!;
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'contact.vcard');
      expect(parsed.parts![1].decodeContentText(), '''
BEGIN:VCARD\r
VERSION:4.0\r
UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1\r
FN:J. Doe\r
N:Doe;J.;;;\r
EMAIL;PID=1.1:jdoe@example.com\r
EMAIL;PID=2.1:boss@example.com\r
EMAIL;PID=2.2:ceo@example.com\r
TEL;PID=1.1;VALUE=uri:tel:+1-555-555-5555\r
TEL;PID=2.1,2.2;VALUE=uri:tel:+1-666-666-6666\r
CLIENTPIDMAP:1;urn:uuid:53e374d9-337e-4727-8803-a1e9c14e0556\r
CLIENTPIDMAP:2;urn:uuid:1f762d2b-03c4-4a83-9a03-75ff658a6eee\r
END:VCARD\r
\r
''');
      expect(parsed.parts![2].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.imageJpeg);
      expect(parsed.parts![2].getHeaderContentType()!.parameters['name'],
          'helloworld.jpg');
      disposition = parsed.parts![2].getHeaderContentDisposition()!;
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'helloworld.jpg');
      expect(parsed.parts![2].decodeContentBinary(),
          Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
    });
  });

  group('reply', () {
    test('reply simple text msg without quote', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Me', 'recipient@domain.com'),
        MailAddress('Group Member', 'group.member@domain.com')
      ];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder =
          MessageBuilder.prepareReplyToMessage(originalMessage, to.first)
            ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Re: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(
          message.getHeaderValue('to'),
          '"Personal Name" <sender@domain.com>, "Group Member" '
          '<group.member@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'), '7bit');
      expect(message.decodeContentText(), 'Here is my reply');
    });

    test('reply just sender 1', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in '
          'the end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, to.first,
          replyAll: false)
        ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Re: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(
          message.getHeaderValue('to'), '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('cc'), null);
    });

    test('reply just sender 2', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Me', 'recipient@domain.com'),
        MailAddress('Group Member', 'group.member@domain.com')
      ];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in '
          'the end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, to.first,
          replyAll: false)
        ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Re: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(
          message.getHeaderValue('to'), '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('cc'), null);
    });

    test('reply simple text msg with quote', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, to.first,
          quoteOriginalText: true);
      replyBuilder.text = 'Here is my reply\r\n${replyBuilder.text}';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Re: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(
          message.getHeaderValue('to'), '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'), '7bit');
      const expectedStart = 'Here is my reply\r\n>On ';
      expect(message.decodeContentText()?.substring(0, expectedStart.length),
          expectedStart);
      const expectedEnd = 'sentence is finished.\r\n>';
      expect(
          message.decodeContentText()?.substring(
              message.decodeContentText()!.length - expectedEnd.length),
          expectedEnd);
    });

    test('reply multipart text msg with quote', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalBuilder =
          MessageBuilder.prepareMultipartAlternativeMessage()
            ..from = [from]
            ..to = to
            ..cc = cc
            ..subject = subject
            ..addTextPlain(text)
            ..addTextHtml('<p>$text</p>');
      final originalMessage = originalBuilder.buildMimeMessage();
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, to.first,
          quoteOriginalText: true);
      final textPlain = replyBuilder.getTextPlainPart()!;
      expect(textPlain, isNotNull);
      textPlain.text = 'Here is my reply.\r\n${textPlain.text}';
      final textHtml = replyBuilder.getTextHtmlPart()!;
      expect(textHtml, isNotNull);
      textHtml.text = '<p>Here is my reply.</p>\r\n${textHtml.text}';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Re: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(
          message.getHeaderValue('to'), '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
      expect(message.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartAlternative);
      //expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      const expectedStart = 'Here is my reply.\r\n>On ';
      final plainText = message.decodeTextPlainPart()!;
      expect(plainText.substring(0, expectedStart.length), expectedStart);
      const expectedEnd = 'sentence is finished.\r\n>';
      expect(plainText.substring(plainText.length - expectedEnd.length),
          expectedEnd);
      final html = message.decodeTextHtmlPart()!;
      const expectedStart2 = '<p>Here is my reply.</p>\r\n<blockquote><br/>On ';
      expect(html.substring(0, expectedStart2.length), expectedStart2);
      const expectedEnd2 = 'sentence is finished.\r\n</p></blockquote>';
      expect(html.substring(html.length - expectedEnd2.length), expectedEnd2);
    });

    test('reply to myself', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder =
          MessageBuilder.prepareReplyToMessage(originalMessage, from)
            ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
    });

    test('reply to myself with alias', () {
      final from = MailAddress('Alias Name', 'sender.alias@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, MailAddress('Personal Name', 'sender@domain.com'),
          aliases: [from])
        ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      expect(message.getHeaderValue('to'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
      expect(message.getHeaderValue('from'),
          '"Alias Name" <sender.alias@domain.com>');
    });

    test('reply to myself with plus alias', () {
      final from = MailAddress('Alias Name', 'sender+alias@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, MailAddress('Personal Name', 'sender@domain.com'),
          handlePlusAliases: true)
        ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      expect(message.getHeaderValue('to'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
      expect(message.getHeaderValue('from'),
          '"Alias Name" <sender+alias@domain.com>');
    });

    test('reply simple text msg with alias recognition', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient.full@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyFrom = MailAddress('Me', 'recipient@domain.com');
      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, replyFrom,
          aliases: [MailAddress('Me Full', 'recipient.full@domain.com')])
        ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('from'),
          '"Me Full" <recipient.full@domain.com>');
      expect(
          message.getHeaderValue('to'), '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
    });

    test('reply simple text msg with +alias recognition', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient+alias@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final replyFrom = MailAddress('Me', 'recipient@domain.com');
      final replyBuilder = MessageBuilder.prepareReplyToMessage(
          originalMessage, replyFrom,
          handlePlusAliases: true)
        ..text = 'Here is my reply';
      final message = replyBuilder.buildMimeMessage();
      // print('reply:');
      // print(message.renderMessage());
      expect(
          message.getHeaderValue('from'), '"Me" <recipient+alias@domain.com>');
      expect(
          message.getHeaderValue('to'), '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('cc'),
          '"=?utf8?Q?One_m=C3=B6re?=" <one.more@domain.com>');
    });
  });
  group('forward', () {
    test('forward simple text msg', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalMessage = MessageBuilder.buildSimpleTextMessage(
          from, to, text,
          cc: cc, subject: subject);
      // print('original:');
      // print(originalMessage.renderMessage());

      final forwardBuilder =
          MessageBuilder.prepareForwardMessage(originalMessage, from: to.first)
            ..to = [
              MailAddress('First', 'first@domain.com'),
              MailAddress('Second', 'second@domain.com')
            ];
      forwardBuilder.text =
          'This should be interesting:\r\n${forwardBuilder.text}';
      final message = forwardBuilder.buildMimeMessage();
      // print('forward:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Fwd: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('to'),
          '"First" <first@domain.com>, "Second" <second@domain.com>');
      expect(message.getHeaderValue('Content-Type'),
          'text/plain; charset="utf-8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'),
          'quoted-printable');
      const expectedStart = 'This should be interesting:\r\n'
          '>---------- Original Message ----------\r\n'
          '>From: "Personal Name" <sender@domain.com>\r\n'
          '>To: "Me" <recipient@domain.com>\r\n'
          '>CC: "One m=C3=B6re" <one.more@domain.com>';
      expect(getRawBodyText(message)?.substring(0, expectedStart.length),
          expectedStart);
      const expectedEnd = 'sentence is finished.\r\n>';
      expect(
          getRawBodyText(message)
              ?.substring(getRawBodyText(message)!.length - expectedEnd.length),
          expectedEnd);
    });

    test('forward multipart text msg', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalBuilder =
          MessageBuilder.prepareMultipartAlternativeMessage()
            ..from = [from]
            ..to = to
            ..cc = cc
            ..subject = subject
            ..addTextPlain(text)
            ..addTextHtml('<p>$text</p>');
      final originalMessage = originalBuilder.buildMimeMessage();
      // print('original:');
      // print(originalMessage.renderMessage());

      final forwardBuilder =
          MessageBuilder.prepareForwardMessage(originalMessage, from: to.first)
            ..to = [
              MailAddress('First', 'first@domain.com'),
              MailAddress('Second', 'second@domain.com')
            ];
      final textPlain = forwardBuilder.getTextPlainPart()!;
      textPlain.text = 'This should be interesting:\r\n${textPlain.text}';
      final textHtml = forwardBuilder.getTextHtmlPart()!;
      textHtml.text = '<p>This should be interesting:</p>\r\n${textHtml.text}';
      final message = forwardBuilder.buildMimeMessage();
      // print('forward:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Fwd: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('to'),
          '"First" <first@domain.com>, "Second" <second@domain.com>');
      expect(message.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartAlternative);
      const expectedStart = 'This should be interesting:\r\n'
          '>---------- Original Message ----------\r\n'
          '>From: "Personal Name" <sender@domain.com>\r\n'
          '>To: "Me" <recipient@domain.com>\r\n'
          '>CC: "One möre" <one.more@domain.com>';
      final plainText = message.decodeTextPlainPart();
      expect(plainText, isNotNull);
      expect(plainText!.substring(0, expectedStart.length), expectedStart);
      const expectedEnd = 'sentence is finished.\r\n>';
      expect(plainText.substring(plainText.length - expectedEnd.length),
          expectedEnd);
      //expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      const expectedStart2 = '<p>This should be interesting:</p>\r\n'
          '<br/><blockquote>---------- Original Message ----------<br/>\r\n'
          'From: "Personal Name" <sender@domain.com><br/>\r\n'
          'To: "Me" <recipient@domain.com><br/>\r\n'
          'CC: "One möre" <one.more@domain.com><br/>';
      final htmlText = message.decodeTextHtmlPart();
      expect(htmlText, isNotNull);
      expect(htmlText!.substring(0, expectedStart2.length), expectedStart2);
      const expectedEnd2 = 'sentence is finished.\r\n</p></blockquote>';
      expect(htmlText.substring(htmlText.length - expectedEnd2.length),
          expectedEnd2);
    });

    test('forward multipart msg with attachments', () async {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalBuilder =
          MessageBuilder.prepareMultipartAlternativeMessage()
            ..from = [from]
            ..to = to
            ..cc = cc
            ..subject = subject
            ..addTextPlain(text)
            ..addTextHtml('<p>$text</p>');
      final file = File('test/smtp/testimage.jpg');
      await originalBuilder.addFile(file, MediaSubtype.imageJpeg.mediaType);
      final originalMessage = originalBuilder.buildMimeMessage();
      // print('original:');
      // print(originalMessage.renderMessage());

      final forwardBuilder =
          MessageBuilder.prepareForwardMessage(originalMessage, from: to.first)
            ..to = [
              MailAddress('First', 'first@domain.com'),
              MailAddress('Second', 'second@domain.com')
            ];
      final textPlain = forwardBuilder.getTextPlainPart()!;
      expect(textPlain, isNotNull);
      expect(textPlain.text, isNotNull);
      textPlain.text = 'This should be interesting:\r\n${textPlain.text}';
      final textHtml = forwardBuilder.getTextHtmlPart()!;
      expect(textHtml, isNotNull);
      expect(textHtml.text, isNotNull);
      textHtml.text = '<p>This should be interesting:</p>\r\n${textHtml.text}';
      final message = forwardBuilder.buildMimeMessage();
      // print('forward:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Fwd: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('to'),
          '"First" <first@domain.com>, "Second" <second@domain.com>');
      expect(message.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartAlternative);
      const expectedStart = 'This should be interesting:\r\n'
          '>---------- Original Message ----------\r\n'
          '>From: "Personal Name" <sender@domain.com>\r\n'
          '>To: "Me" <recipient@domain.com>\r\n'
          '>CC: "One möre" <one.more@domain.com>';
      final plainText = message.decodeTextPlainPart()!;
      expect(plainText.substring(0, expectedStart.length), expectedStart);
      const expectedEnd = 'sentence is finished.\r\n>';
      expect(plainText.substring(plainText.length - expectedEnd.length),
          expectedEnd);
      //expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      const expectedStart2 = '<p>This should be interesting:</p>\r\n'
          '<br/><blockquote>---------- Original Message ----------<br/>\r\n'
          'From: "Personal Name" <sender@domain.com><br/>\r\n'
          'To: "Me" <recipient@domain.com><br/>\r\n'
          'CC: "One möre" <one.more@domain.com><br/>';
      final htmlText = message.decodeTextHtmlPart()!;
      expect(htmlText.substring(0, expectedStart2.length), expectedStart2);
      const expectedEnd2 = 'sentence is finished.\r\n</p></blockquote>';
      expect(htmlText.substring(htmlText.length - expectedEnd2.length),
          expectedEnd2);
      expect(message.parts!.length, 3);
      final filePart = message.parts![2];
      final dispositionHeader = filePart.getHeaderContentDisposition()!;
      expect(dispositionHeader, isNotNull);
      expect(dispositionHeader.disposition, ContentDisposition.attachment);
      expect(dispositionHeader.filename, 'testimage.jpg');
      expect(dispositionHeader.size, 13390);
      final binary = filePart.decodeContentBinary();
      expect(binary, isNotEmpty);
      final contentType = filePart.getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType?.mediaType.sub, MediaSubtype.imageJpeg);
    });

    test('forward multipart msg with attachments without quote', () async {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [MailAddress('Me', 'recipient@domain.com')];
      final cc = [MailAddress('One möre', 'one.more@domain.com')];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final originalBuilder = MessageBuilder.prepareMessageWithMediaType(
          MediaSubtype.multipartMixed)
        ..from = [from]
        ..to = to
        ..cc = cc
        ..subject = subject;
      originalBuilder.addPart(mediaSubtype: MediaSubtype.multipartAlternative)
        ..addTextPlain(text)
        ..addTextHtml('<p>$text</p>');
      final file = File('test/smtp/testimage.jpg');
      await originalBuilder.addFile(file, MediaSubtype.imageJpeg.mediaType);
      final originalMessage = originalBuilder.buildMimeMessage();
      // print('original:');
      // print(originalMessage.renderMessage());
      final forwardBuilder = MessageBuilder.prepareForwardMessage(
          originalMessage,
          from: to.first,
          quoteMessage: false)
        ..to = [
          MailAddress('First', 'first@domain.com'),
          MailAddress('Second', 'second@domain.com')
        ];
      // ..addTextPlain(text)
      // ..addTextHtml('<p>$text</p>');

      final message = forwardBuilder.buildMimeMessage();
      // print('forward:');
      // print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Fwd: Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'), '"Me" <recipient@domain.com>');
      expect(message.getHeaderValue('to'),
          '"First" <first@domain.com>, "Second" <second@domain.com>');
      expect(message.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);

      expect(message.parts!.length, 1);
      final filePart = message.parts![0];

      final dispositionHeader = filePart.getHeaderContentDisposition()!;
      expect(dispositionHeader, isNotNull);
      expect(dispositionHeader.disposition, ContentDisposition.attachment);
      expect(dispositionHeader.filename, 'testimage.jpg');
      expect(dispositionHeader.size, 13390);
      final binary = filePart.decodeContentBinary();
      expect(binary, isNotEmpty);
      final contentType = filePart.getHeaderContentType()!;
      // print(contentType.render());
      expect(contentType, isNotNull);
      expect(contentType.mediaType.sub, MediaSubtype.imageJpeg);
    });
  });

  group('File', () {
    test('addFile', () async {
      final builder = MessageBuilder.prepareMultipartMixedMessage()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..addTextPlain('Hello world!');

      final file = File('test/smtp/testimage.jpg');
      await builder.addFile(file, MediaSubtype.imageJpeg.mediaType);
      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      //print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 2);
      expect(parsed.parts![0].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.imageJpeg);
      final disposition = parsed.parts![1].getHeaderContentDisposition()!;
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'testimage.jpg');
      expect(disposition.size, isNotNull);
      expect(disposition.modificationDate, isNotNull);
      final decoded = parsed.parts![1].decodeContentBinary();
      expect(decoded, isNotNull);
      final fileData = await file.readAsBytes();
      expect(decoded, fileData);
    });

    test('addFile with large image', () async {
      final builder = MessageBuilder.prepareMultipartMixedMessage()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..addTextPlain('Hello world!');

      final file = File('test/smtp/testimage-large.jpg');
      await builder.addFile(file, MediaSubtype.imageJpeg.mediaType);
      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      // print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 2);
      expect(parsed.parts![0].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.imageJpeg);
      final disposition = parsed.parts![1].getHeaderContentDisposition()!;
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'testimage-large.jpg');
      expect(disposition.size, isNotNull);
      expect(disposition.modificationDate, isNotNull);
      final decoded = parsed.parts![1].decodeContentBinary();
      expect(decoded, isNotNull);
      final fileData = await file.readAsBytes();
      expect(decoded, fileData);
    });
  });

  group('Binary', () {
    test('addBinary', () {
      final builder = MessageBuilder.prepareMultipartMixedMessage()
        ..from = [MailAddress('Personal Name', 'sender@domain.com')]
        ..to = [
          MailAddress('Recipient Personal Name', 'recipient@domain.com'),
          MailAddress('Other Recipient', 'other@domain.com')
        ]
        ..addTextPlain('Hello world!');
      final data = Uint8List.fromList([127, 32, 64, 128, 255]);
      builder.addBinary(data, MediaSubtype.imageJpeg.mediaType);
      final message = builder.buildMimeMessage();
      final rendered = message.renderMessage();
      //print(rendered);
      final parsed = MimeMessage.parseFromText(rendered);
      expect(parsed.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts!.length, 2);
      expect(parsed.parts![0].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts![0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts![1].getHeaderContentType()!.mediaType.sub,
          MediaSubtype.imageJpeg);
      final disposition = parsed.parts![1].getHeaderContentDisposition()!;
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      final decoded = parsed.parts![1].decodeContentBinary();
      expect(decoded, isNotNull);
      expect(decoded, data);
    });
  });

  group('Helper methods', () {
    test('createReplySubject', () {
      expect(MessageBuilder.createReplySubject('Hello'), 'Re: Hello');
      expect(
          MessageBuilder.createReplySubject('Hello',
              defaultReplyAbbreviation: 'AW'),
          'AW: Hello');
      expect(MessageBuilder.createReplySubject('Re: Hello'), 'Re: Hello');
      expect(MessageBuilder.createReplySubject('AW: Hello'), 'AW: Hello');
      expect(MessageBuilder.createReplySubject('[External] Re: Hello'),
          'Re: Hello');
      expect(MessageBuilder.createReplySubject('[External] AW: Hello'),
          'AW: Hello');
    });

    test('createFowardSubject', () {
      expect(MessageBuilder.createForwardSubject('Hello'), 'Fwd: Hello');
      expect(
          MessageBuilder.createForwardSubject('Hello',
              defaultForwardAbbreviation: 'WG'),
          'WG: Hello');
      expect(MessageBuilder.createForwardSubject('Fwd: Hello'), 'Fwd: Hello');
      expect(MessageBuilder.createForwardSubject('WG: Hello'), 'WG: Hello');
      expect(MessageBuilder.createForwardSubject('[External] FWD: Hello'),
          'FWD: Hello');
      expect(MessageBuilder.createForwardSubject('[External] Fwd: Hello'),
          'Fwd: Hello');
    });

    test('createRandomId', () {
      var random = MessageBuilder.createRandomId();
      //print(random);
      expect(random, isNotNull);
      random = MessageBuilder.createRandomId(length: 1);
      expect(random, isNotNull);
      expect(random.length, 1);
      random = MessageBuilder.createRandomId(length: 20);
      expect(random, isNotNull);
      expect(random.length, 20);
    });

    test('fillTemplate', () {
      final from = MailAddress('Personal Name', 'sender@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      const subject = 'Hello from test';
      const text =
          'Hello World - here\s some text that should spans two lines in the '
          'end when this sentence is finished.\r\n';
      final message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject);
      var template = 'On <date> <from> wrote:';
      var filled = MessageBuilder.fillTemplate(template, message);
      //print(template + ' -> ' + filled);
      expect(filled.substring(0, 3), 'On ');
      expect(filled.substring(filled.length - ' wrote:'.length), ' wrote:');
      expect(
          filled.substring(filled.length -
              ' "Personal Name" <sender@domain.com> wrote:'.length),
          ' "Personal Name" <sender@domain.com> wrote:');
      template = '---------- Original Message ----------\r\n'
          'From: <from>\r\n'
          '[[to To: <to>\r\n]]'
          '[[cc CC: <cc>\r\n]]'
          'Date: <date>\r\n'
          '[[subject Subject: <subject>\r\n]]';
      filled = MessageBuilder.fillTemplate(template, message);
      //print(template + ' -> ' + filled);

      final optionalInclusionsExpression = RegExp(r'\[\[\w+\s[\s\S]+?\]\]');
      final match = optionalInclusionsExpression.firstMatch(template)!;
      expect(match, isNotNull);
      expect(match.group(0), '[[to To: <to>\r\n]]');

      final lines = filled.split('\r\n');
      expect(lines.length, 6);
      expect(lines[0], '---------- Original Message ----------');
      expect(lines[1], 'From: "Personal Name" <sender@domain.com>');
      expect(lines[2], 'To: "Recipient Personal Name" <recipient@domain.com>');
      expect(lines[4], 'Subject: Hello from test');
      expect(lines[5], '');
    });
  });

  group('Content type', () {
    test('MultiPart', () {
      final builder = MessageBuilder()
        ..from = [MailAddress('personalName', 'someone@domain.com')]
        ..setContentType(MediaSubtype.multipartMixed.mediaType);
      final message = builder.buildMimeMessage();
      final contentType = message.getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType!.boundary, isNotNull);
      expect(contentType.mediaType.top, MediaToptype.multipart);
      expect(contentType.mediaType.sub, MediaSubtype.multipartMixed);
      //print(message.renderMessage());
    });
  });
  group('mailto', () {
    test('adddress, subject, body', () {
      final from = MailAddress('Me', 'me@domain.com');
      final mailto =
          Uri.parse('mailto:recpient@domain.com?subject=hello&body=world');
      final builder = MessageBuilder.prepareMailtoBasedMessage(mailto, from);
      final message = builder.buildMimeMessage();
      expect(message.getHeaderValue('subject'), 'hello');
      expect(message.getHeaderValue('to'), 'recpient@domain.com');
      expect(message.decodeContentText(), 'world');
    });
    test('several adddresses', () {
      final from = MailAddress('Me', 'me@domain.com');
      final mailto = Uri.parse('mailto:recpient@domain.com,another@domain.com');
      final builder = MessageBuilder.prepareMailtoBasedMessage(mailto, from);
      final message = builder.buildMimeMessage();
      expect(message.getHeaderValue('to'),
          'recpient@domain.com, another@domain.com');
    });

    test('to, subject, body', () {
      final from = MailAddress('Me', 'me@domain.com');
      final mailto =
          Uri.parse('mailto:?to=recpient@domain.com&subject=hello&body=world');
      final builder = MessageBuilder.prepareMailtoBasedMessage(mailto, from);
      final message = builder.buildMimeMessage();
      expect(message.getHeaderValue('subject'), 'hello');
      expect(message.getHeaderValue('to'), 'recpient@domain.com');
      expect(message.decodeContentText(), 'world');
    });
    test('address & to, subject, body', () {
      final from = MailAddress('Me', 'me@domain.com');
      final mailto =
          Uri.parse('mailto:recpient@domain.com?to=another@domain.com&'
              'subject=hello&body=world');
      final builder = MessageBuilder.prepareMailtoBasedMessage(mailto, from);
      final message = builder.buildMimeMessage();
      expect(message.getHeaderValue('subject'), 'hello');
      expect(message.getHeaderValue('to'),
          'recpient@domain.com, another@domain.com');
      expect(message.decodeContentText(), 'world');
    });

    test('address, cc, subject, body, in-reply-to', () {
      final from = MailAddress('Me', 'me@domain.com');
      final mailto = Uri.parse(
          'mailto:recpient@domain.com?cc=another@domain.com&subject=hello'
          '%20wörld&body=let%20me%20unsubscribe&in-reply-to=%3C3469A91.D10A'
          'F4C@example.com%3E');
      final builder = MessageBuilder.prepareMailtoBasedMessage(mailto, from);
      final message = builder.buildMimeMessage();
      expect(message.getHeaderValue('subject'), 'hello w=?utf8?Q?=C3=B6?=rld');
      expect(message.getHeaderValue('to'), 'recpient@domain.com');
      expect(message.getHeaderValue('cc'), 'another@domain.com');
      expect(message.decodeContentText(), 'let me unsubscribe');
      expect(message.getHeaderValue('in-reply-to'),
          '<3469A91.D10AF4C@example.com>');
    });
  });

  group('addMessagePart', () {
    test('add text message', () {
      final from = MailAddress('Me', 'me@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      const subject = 'Original Message';
      const text = 'Hello World - this is the original message';
      final original = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject);
      final builder = MessageBuilder()
        ..addMessagePart(original)
        ..subject = 'message with attached message'
        ..text = 'hello world';
      final message = builder.buildMimeMessage();
      //print(message.renderMessage());
      final parts = message.parts!;
      expect(parts.length, 2);
      expect(parts[0].isTextMediaType(), isTrue);
      expect(parts[0].decodeContentText(), 'hello world');
      expect(parts[1].mediaType.sub, MediaSubtype.messageRfc822);
      expect(parts[1].decodeFileName(), 'Original Message.eml');
      final embeddedMessage = parts[1].decodeContentMessage();
      expect(embeddedMessage, isNotNull);
      expect(embeddedMessage!.decodeTextPlainPart(),
          'Hello World - this is the original message');
    });

    test('add text message with quotes in subject', () {
      final from = MailAddress('Me', 'me@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      const subject = '"Original" Message';
      const text = 'Hello World - this is the original message';
      final original = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject);
      final builder = MessageBuilder()
        ..addMessagePart(original)
        ..subject = 'message with attached message'
        ..text = 'hello world';
      final message = builder.buildMimeMessage();
      // print(message.renderMessage());
      final parts = message.parts!;
      expect(parts.length, 2);
      expect(parts[0].isTextMediaType(), isTrue);
      expect(parts[0].decodeContentText(), 'hello world');
      expect(parts[1].mediaType.sub, MediaSubtype.messageRfc822);
      expect(parts[1].decodeFileName(), '"Original" Message.eml');
      final embeddedMessage = parts[1].decodeContentMessage();
      expect(embeddedMessage, isNotNull);
      expect(embeddedMessage!.decodeTextPlainPart(),
          'Hello World - this is the original message');
    });

    test('add multipart/alternative message', () {
      final from = MailAddress('Me', 'me@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      final originalBuilder =
          MessageBuilder.prepareMultipartAlternativeMessage()
            ..from = [from]
            ..to = to
            ..subject = 'Original Message'
            ..addTextPlain('Hello World - this is the original message')
            ..addTextHtml(
                '<html><body><p>Hello World - this is the original message'
                '</p></body></html>');
      final original = originalBuilder.buildMimeMessage();
      final builder = MessageBuilder()
        ..addMessagePart(original)
        ..subject = 'message with attached message'
        ..text = 'hello world';
      final message = builder.buildMimeMessage();
      // print(message.renderMessage());
      final parts = message.parts!;
      expect(parts.length, 2);
      expect(parts[0].isTextMediaType(), isTrue);
      expect(parts[0].decodeContentText(), 'hello world');
      expect(parts[1].mediaType.sub, MediaSubtype.messageRfc822);
      expect(parts[1].decodeFileName(), 'Original Message.eml');
      final embeddedMessage = parts[1].decodeContentMessage();
      expect(embeddedMessage, isNotNull);
      expect(embeddedMessage!.decodeTextPlainPart(),
          'Hello World - this is the original message\r\n');
    });

    test('add multipart/mixed message', () {
      final from = MailAddress('Me', 'me@domain.com');
      final to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com')
      ];
      final originalBuilder = MessageBuilder()
        ..from = [from]
        ..to = to
        ..subject = 'Original Message'
        ..addTextPlain('Hello World - this is the original message')
        ..addTextHtml('<html><body><p>Hello World - this is the original '
            'message</p></body></html>')
        ..addBinary(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 0]),
            MediaSubtype.applicationOctetStream.mediaType,
            filename: 'mydata.bin');
      final original = originalBuilder.buildMimeMessage();
      final builder = MessageBuilder()
        ..addMessagePart(original)
        ..subject = 'message with attached message'
        ..text = 'hello world';
      final message = builder.buildMimeMessage();
      // print(message.renderMessage());
      final parts = message.parts!;
      expect(parts.length, 2);
      expect(parts[0].isTextMediaType(), isTrue);
      expect(parts[0].decodeContentText(), 'hello world');
      expect(parts[1].mediaType.sub, MediaSubtype.messageRfc822);
      expect(parts[1].decodeFileName(), 'Original Message.eml');
      final embeddedMessage = parts[1].decodeContentMessage();
      expect(embeddedMessage, isNotNull);
      expect(embeddedMessage!.mediaType.sub, MediaSubtype.multipartMixed);
      expect(embeddedMessage.parts!.length, 3);
      expect(embeddedMessage.decodeTextPlainPart(),
          'Hello World - this is the original message\r\n');
      expect(embeddedMessage.parts!.length, 3);
      expect(embeddedMessage.parts![2].decodeContentBinary(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]);
    });

    test('real world test', () {
      final original = MimeMessage.parseFromText(complexMessageText);
      expect(
          original.decodeSubject(),
          'Ihre Telekom Mobilfunk RechnungOnline Januar 2021 (Adresse: '
          '1234567 89, Kundenkonto: 123)');
      final builder = MessageBuilder()
        ..addMessagePart(original)
        ..subject = 'message with attached message';
      builder.getPart(MediaSubtype.multipartAlternative, recursive: false) ??
          builder.addPart(
              mediaSubtype: MediaSubtype.multipartAlternative, insert: true)
        ..addTextPlain('hello world')
        ..addTextHtml('<p>hello world</p>');
      final message = builder.buildMimeMessage();
      //print(message.renderMessage());
      final parts = message.parts!;
      expect(parts.length, 2);
      expect(parts[0].mediaType.sub, MediaSubtype.multipartAlternative);
      expect(parts[0].getHeaderValue('content-transfer-encoding'), isNull);
      expect(parts[0].parts![0].decodeContentText(), 'hello world');
      expect(parts[1].mediaType.sub, MediaSubtype.messageRfc822);
      expect(
          parts[1].decodeFileName(),
          'Ihre Telekom Mobilfunk RechnungOnline Januar 2021 (Adresse: 1234567 '
          '89, Kundenkonto: 123).eml');
      final embeddedMessage = parts[1].decodeContentMessage();
      expect(embeddedMessage, isNotNull);
      expect(embeddedMessage!.mediaType.sub, MediaSubtype.multipartMixed);
      expect(embeddedMessage.parts!.length, 2);
      expect(embeddedMessage.parts![0].mediaType.sub,
          MediaSubtype.multipartAlternative);
      expect(embeddedMessage.decodeTextPlainPart()!.startsWith('Guten Tag '),
          isTrue);
      expect(embeddedMessage.parts![1].decodeFileName(),
          'Rechnung_2021_01_27317621000841.pdf');
      expect(embeddedMessage.parts![1].decodeContentBinary()!.sublist(0, 9),
          [37, 80, 68, 70, 45, 49, 46, 53, 10]);
      final parsedAgain = MimeMessage.parseFromText(message.renderMessage());
      final parsedAgainEmbedded = parsedAgain.parts![1].decodeContentMessage()!;
      expect(
          parsedAgainEmbedded.decodeTextPlainPart()!.startsWith('Guten Tag '),
          isTrue);
      expect(parsedAgainEmbedded.parts![1].decodeFileName(),
          'Rechnung_2021_01_27317621000841.pdf');
      expect(parsedAgainEmbedded.parts![1].decodeContentBinary()!.sublist(0, 9),
          [37, 80, 68, 70, 45, 49, 46, 53, 10]);
    });
  });

  group('MDNs', () {
    test('buildReadReceipt', () {
      final originalMessage = MimeMessage.parseFromText(complexMessageText);
      originalMessage.addHeader(MailConventions.headerDispositionNotificationTo,
          originalMessage.fromEmail);
      final finalRecipient = MailAddress('My Name', 'recipient@domain.com');
      final mdn =
          MessageBuilder.buildReadReceipt(originalMessage, finalRecipient);
      // print(mdn.renderMessage());
      expect(mdn.to, isNotEmpty);
      expect(mdn.to?.first.email, originalMessage.fromEmail);
      expect(mdn.mediaType.sub, MediaSubtype.multipartReport);
      expect(mdn.decodeTextPlainPart(), isNotEmpty);
      expect(mdn.decodeSubject(), isNotNull);
      final part = mdn
          .getPartWithMediaSubtype(MediaSubtype.messageDispositionNotification);
      expect(part, isNotNull);
      //print(part!.decodeContentText());
      //expect(part!.decodeDispositionNotification())
    });
  });
}

const String complexMessageText = '''
Return-Path: <Kundenservice.Rechnungonline@telekom.de>\r
Received: from AWMAIL121.telekom.de ([194.25.225.147]) by mx.kundenserver.de\r
 (mxeue009 [212.227.15.41]) with ESMTPS (Nemesis) id 1Ml5Rc-1lbqtm34yi-00lUqM\r
 for <recipient@domain.com>; Thu, 11 Feb 2021 18:33:10 +0100\r
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;\r
  d=telekom.de; i=@telekom.de; q=dns/txt; s=dtag;\r
  t=1613064790; x=1644600790;\r
  h=message-id:date:reply-to:to:subject:mime-version:from;\r
  bh=4vLAh5zEUU6anl5LtECqWZ9saDTN5t4Fm1DsX3ESDnM=;\r
  b=OmIkORmUche6cTg7qSzdOedxm89GO4Ds+BLyR/90l5cN+kQvhmyrybg5\r
   FcGiLFZGXpA2kk3C7sIx2thk8kg5JO2ABqXLOfauPrbqD6zWUcABI/mbE\r
   6528JRE8wsWw72AGdmfe77aylYnUg/3sl6I3VoL8Eu/u0KfQCN1v0yavT\r
   N7B5+ZcIFVDrnPDsPdbdWGQmn3XBCWDROKePSyfdehjuAO9IdbNQi+3wB\r
   76wtIrwtr2E7qasQlrj2lqKgjL4x/NEsh+grW9qs6tX6MDmCLx3iilUw6\r
   yUp8o6KryC0aMeJesxvmzmaR8pCuVFb0UUKR6h/g2rWeoDm5ku+g8XB8B\r
   A==;\r
IronPort-SDR: VxF26s0FdetMHR5JRLP0L5hbEtpatw3K8/ZGViA+0IOAahqJ370uq8lBmeqlOR+En0TiGTvysE\r
 x8A75djr15ObnQt+J0wnsC1Fg8Yj1B7Uc=\r
From: Kundenservice.Rechnungonline@telekom.de\r
X-IronPort-AV: E=Sophos;i="5.81,170,1610406000";\r
   d="pdf'?scan'208,217";a="479162390"\r
X-MGA-submission: =?us-ascii?q?MDEm1u9470rHCgAHtYzzhb1psCrUxbP110X++4?=\r
 =?us-ascii?q?WCPLLvoG5rR/jceXacvoRs72CA3MMfu9abKjR/kfmiWDEBkdkk9I+q+m?=\r
 =?us-ascii?q?nOjtro3+4vYV+op3hpzkj3UpaeLVQa7J2XO+lxImRrMF60Ob5Uu62T4g?=\r
 =?us-ascii?q?iH0yINyX3uTzHlDKQI6zbPzYMhjh8IaI70AJAl84AP/jQ=3D?=\r
Received: from qde7xg.de.t-internal.com ([10.169.152.30])\r
  by AWMAIL121.dmznet.de.t-internal.com with ESMTP; 11 Feb 2021 18:33:10 +0100\r
Received: from qde5nb (QDE5NB [10.105.40.71])\r
        by QDE7XG.de.t-internal.com (Postfix) with ESMTP id 41BB91585391\r
        for <recipient@domain.com>; Thu, 11 Feb 2021 17:57:30 +0100 (CET)\r
Message-ID: <1447244645.1613062650263.JavaMail.rechnung-online@telekom.de>\r
Date: Thu, 11 Feb 2021 17:57:30 +0100 (CET)\r
Reply-To: noreply@telekom.de\r
To: recipient@domain.com\r
Subject: Ihre Telekom Mobilfunk RechnungOnline Januar 2021 (Adresse: 1234567\r
 89, Kundenkonto: 123)\r
MIME-Version: 1.0\r
Content-Type: multipart/mixed;\r
        boundary="----=_Part_2450395_-60847697.1613062650261"\r
Envelope-To: <recipient@domain.com>\r
Authentication-Results: mqeue011.server.lan; dkim=pass header.i=@telekom.de\r
x-tdresult: feb8e846-d674-402a-b71a-3c2bc1e37567;c0aae587-6cd1-41fe-8a27-41c495be5c1b;1;0;1;0\r
x-tdcapabilities:\r
X-Spam-Flag: NO\r
\r
------=_Part_2450395_-60847697.1613062650261\r
Content-Type: multipart/alternative;\r
        boundary="----=_Part_2450396_1831469312.1613062650261"\r
\r
------=_Part_2450396_1831469312.1613062650261\r
Content-Type: text/plain; charset=iso-8859-15\r
Content-Transfer-Encoding: quoted-printable\r
\r
Guten Tag XXX,\r
\r
------=_Part_2450396_1831469312.1613062650261\r
Content-Type: text/html; charset=iso-8859-15\r
Content-Transfer-Encoding: quoted-printable\r
\r
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.=\r
w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html xmlns=3D"http://www.w3.=\r
org/1999/xhtml"><head><meta http-equiv=3D"Content-Type" content=3D"text/htm=\r
l; charset=3DISO-8859-1" /><meta name=3D"viewport" content=3D"width=3Ddevic=\r
e-width, initial-scale=3D1.0"><meta http-equiv=3D"X-UA-Compatible" content=\r
=3D"IE=3Dedge"><title>TELEKOM - ERLEBEN, WAS VERBINDET.</title><meta name=\r
=3D"format-detection" content=3D"telephone=3Dno"></head><body bgcolor=3D#67=\r
6767><center><table width=3D490 border=3D0 bgcolor=\r
=3D#ffffff cellspacing=3D0><td><div sty=\r
le=3D"margin: 25px 30px 25px 25px; color: #444748; background-color: #fffff=\r
f; line-height: 1.4; font-family: Arial; font-size: 17px;">Guten Tag XXX=\r
</div></td></tr></table></center></body></html>\r
------=_Part_2450396_1831469312.1613062650261--\r
\r
------=_Part_2450395_-60847697.1613062650261\r
Content-Type: application/octet-stream;\r
        name=Rechnung_2021_01_27317621000841.pdf\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment;\r
        filename=Rechnung_2021_01_27317621000841.pdf\r
\r
JVBERi0xLjUKJeLjz9MKJUlTSVMgRERERV9QZGYtVjcuNC9sNiAnMjAxOS0wOC0xMyAoYnVpbGQ6\r
Ny40MC4xOTI4MC4xOTMzMCknICAgICAgICAgICAgIA00IDAgb2JqDVsNL0RldmljZVJHQg1dDWVu\r
ZG9iag01IDAgb2JqDVsvUGF0dGVybiA0IDAgUl0gDWVuZG9iag02IDAgb2JqDVsNL0RldmljZUNN\r
WUsNXQ1lbmRvYmoNNyAwIG9iag1bL1BhdHRlcm4gNiAwIFJdIA1lbmRvYmoNOSAwIG9iag08PA0v\r
jPwJy0fIq54MMvIIOcir/YqRkZH3IGc6OcjIG5KzPjnIyFuSM5V8nUcO8qKXWhPJQV6VnGnklCEH\r
uZecQuRMIacUOQeSM07OceSUI2eQnILkjJBLPFDenPjrripCTic5hcnpIqc0+aXVnoJy5FwPyPen\r
nJcm/+n34V5h8m/Xb1d7ZtmLkIeCjIyM/Jn8AOeAsMUNCmVuZHN0cmVhbQplbmRvYmoNMTQgMCBv\r
dCAyIDAgUg0vSW5mbyAxIDAgUg0+Pg1zdGFydHhyZWYNNzk3NzIgICAgIA0lJUVPRg0=\r
------=_Part_2450395_-60847697.1613062650261--\r
\r
''';
