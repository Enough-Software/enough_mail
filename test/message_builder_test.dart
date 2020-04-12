import 'dart:io';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  group('buildSimpleTextMessage', () {
    test('Simple text message', () {
      var from = MailAddress('Personal Name', 'sender@domain.com');
      var to = [MailAddress('Recipient Personal Name', 'recipient@domain.com')];
      var subject = 'Hello from test';
      var text =
          'Hello World - here\s some text that should spans two lines in the end when this sentence is finished.\r\n';
      var message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject);
      //print(message.renderMessage());
      expect(message.getHeaderValue('subject'), 'Hello from test');
      expect(message.getHeaderValue('message-id'), isNotNull);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(
          message.getHeaderValue('Content-Type'), 'text/plain; charset="utf8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      expect(message.bodyRaw,
          'Hello World - here\s some text that should spans two lines in the end when \r\nthis sentence is finished.\r\n');
    });

    test('Simple text message with reply to message', () {
      var from = MailAddress('Personal Name', 'sender@domain.com');
      var to = [MailAddress('Recipient Personal Name', 'recipient@domain.com')];
      var text =
          'Hello World - here\s some text that should spans two lines in the end when this sentence is finished.';
      var replyToMessage = MimeMessage();
      replyToMessage.addHeader('subject', 'Re: Hello from test');
      replyToMessage.addHeader(
          'message-id', '<some-unique-sequence@domain.com>');
      var message = MessageBuilder.buildSimpleTextMessage(from, to, text,
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
      expect(
          message.getHeaderValue('Content-Type'), 'text/plain; charset="utf8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      expect(message.bodyRaw,
          'Hello World - here\s some text that should spans two lines in the end when \r\nthis sentence is finished.');
      //print(message.renderMessage());
    });

    test('Simple chat message', () {
      var from = MailAddress('Personal Name', 'sender@domain.com');
      var to = [MailAddress('Recipient Personal Name', 'recipient@domain.com')];
      var subject = 'Hello from test';
      var text =
          'Hello World - here\s some text that should spans two lines in the end when this sentence is finished.';
      var message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject, isChat: true);
      expect(message.getHeaderValue('subject'), 'Hello from test');
      var id = message.getHeaderValue('message-id');
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$'), isTrue);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(
          message.getHeaderValue('Content-Type'), 'text/plain; charset="utf8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');

      var messageText = message.renderMessage();
      //print(messageText);
      var parsed = MimeMessage()..bodyRaw = messageText;

      expect(parsed.getHeaderValue('subject'), 'Hello from test');
      id = parsed.getHeaderValue('message-id');
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$'), isTrue);
      expect(parsed.getHeaderValue('date'), isNotNull);
      expect(
          parsed.getHeaderValue('from'), '"Personal Name" <sender@domain.com>');
      expect(parsed.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>');
      expect(
          parsed.getHeaderValue('Content-Type'), 'text/plain; charset="utf8"');
      expect(parsed.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      expect(parsed.decodeContentText(),
          'Hello World - here\s some text that should spans two lines in the end when \r\nthis sentence is finished.\r\n');
    });

    test('Simple chat group message', () {
      var from = MailAddress('Personal Name', 'sender@domain.com');
      var to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com'),
        MailAddress('Other Recipient', 'other@domain.com')
      ];
      var subject = 'Hello from test';
      var text =
          'Hello World - here\s some text that should spans two lines in the end when this sentence is finished.';
      var message = MessageBuilder.buildSimpleTextMessage(from, to, text,
          subject: subject, isChat: true, chatGroupId: '1234abc123');
      expect(message.getHeaderValue('subject'), 'Hello from test');
      var id = message.getHeaderValue('message-id');
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$group.1234abc123.'), isTrue);
      expect(message.getHeaderValue('date'), isNotNull);
      expect(message.getHeaderValue('from'),
          '"Personal Name" <sender@domain.com>');
      expect(message.getHeaderValue('to'),
          '"Recipient Personal Name" <recipient@domain.com>; "Other Recipient" <other@domain.com>');
      expect(
          message.getHeaderValue('Content-Type'), 'text/plain; charset="utf8"');
      expect(message.getHeaderValue('Content-Transfer-Encoding'), '8bit');

      var buffer = StringBuffer();
      message.render(buffer);
      var messageText = buffer.toString();
      //print(messageText);
      var parsed = MimeMessage()..bodyRaw = messageText;

      expect(parsed.getHeaderValue('subject'), 'Hello from test');
      id = parsed.getHeaderValue('message-id');
      expect(id, isNotNull);
      expect(id.startsWith('<chat\$group.1234abc123.'), isTrue);
      expect(parsed.getHeaderValue('date'), isNotNull);
      expect(
          parsed.getHeaderValue('from'), '"Personal Name" <sender@domain.com>');
      var toRecipients = parsed.decodeHeaderMailAddressValue('to');
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
          parsed.getHeaderValue('Content-Type'), 'text/plain; charset="utf8"');
      expect(parsed.getHeaderValue('Content-Transfer-Encoding'), '8bit');
      expect(parsed.decodeContentText(),
          'Hello World - here\s some text that should spans two lines in the end when \r\nthis sentence is finished.\r\n');
    });
  });

  group('multipart tests', () {
    test('multipart/alternative with 2 text parts', () {
      var builder = MessageBuilder.prepareMultipartAlternativeMessage();
      builder.from = [MailAddress('Personal Name', 'sender@domain.com')];
      builder.to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com'),
        MailAddress('Other Recipient', 'other@domain.com')
      ];
      builder.addPlainText('Hello world!');
      builder.addHtmlText('<p>Hello world!</p>');
      var message = builder.buildMimeMessage();
      var rendered = message.renderMessage();
      //print(rendered);
      var parsed = MimeMessage()..bodyRaw = rendered;
      expect(parsed.getHeaderContentType().mediaType.sub,
          MediaSubtype.multipartAlternative);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts.length, 2);
      expect(parsed.parts[0].getHeaderContentType().mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts[0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts[1].getHeaderContentType().mediaType.sub,
          MediaSubtype.textHtml);
      expect(parsed.parts[1].decodeContentText(), '<p>Hello world!</p>\r\n');
    });

    test('multipart/mixed with vcard attachment', () {
      var builder = MessageBuilder.prepareMultipartMixedMessage();
      builder.from = [MailAddress('Personal Name', 'sender@domain.com')];
      builder.to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com'),
        MailAddress('Other Recipient', 'other@domain.com')
      ];
      builder.addPlainText('Hello world!');
      builder.addText('''
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
          mediaType: MediaType.fromSubtype(MediaSubtype.textVcard),
          disposition: ContentDispositionHeader.from(
              ContentDisposition.attachment,
              filename: 'contact.vcard'));

      var message = builder.buildMimeMessage();
      var rendered = message.renderMessage();
      //print(rendered);
      var parsed = MimeMessage()..bodyRaw = rendered;
      expect(parsed.getHeaderContentType().mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts.length, 2);
      expect(parsed.parts[0].getHeaderContentType().mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts[0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts[1].getHeaderContentType().mediaType.sub,
          MediaSubtype.textVcard);
      var disposition = parsed.parts[1].getHeaderContentDisposition();
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'contact.vcard');
      expect(parsed.parts[1].decodeContentText(), '''
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
  });

  group('File', () {
    test('addFile', () async {
      var builder = MessageBuilder.prepareMultipartMixedMessage();
      builder.from = [MailAddress('Personal Name', 'sender@domain.com')];
      builder.to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com'),
        MailAddress('Other Recipient', 'other@domain.com')
      ];
      builder.addPlainText('Hello world!');

      var file = File('test/smtp/testimage.jpg');
      await builder.addFile(
          file, MediaType.fromSubtype(MediaSubtype.imageJpeg));
      var message = builder.buildMimeMessage();
      var rendered = message.renderMessage();
      //print(rendered);
      var parsed = MimeMessage()..bodyRaw = rendered;
      expect(parsed.getHeaderContentType().mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts.length, 2);
      expect(parsed.parts[0].getHeaderContentType().mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts[0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts[1].getHeaderContentType().mediaType.sub,
          MediaSubtype.imageJpeg);
      var disposition = parsed.parts[1].getHeaderContentDisposition();
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      expect(disposition.filename, 'testimage.jpg');
      expect(disposition.size, isNotNull);
      expect(disposition.modificationDate, isNotNull);
      var decoded = parsed.parts[1].decodeContentBinary();
      expect(decoded, isNotNull);
      var fileData = await file.readAsBytes();
      expect(decoded, fileData);
    });
  });

  group('Binary', () {
    test('addBinary', () {
      var builder = MessageBuilder.prepareMultipartMixedMessage();
      builder.from = [MailAddress('Personal Name', 'sender@domain.com')];
      builder.to = [
        MailAddress('Recipient Personal Name', 'recipient@domain.com'),
        MailAddress('Other Recipient', 'other@domain.com')
      ];
      builder.addPlainText('Hello world!');
      var data = Uint8List.fromList([127, 32, 64, 128, 255]);
      builder.addBinary(data, MediaType.fromSubtype(MediaSubtype.imageJpeg));
      var message = builder.buildMimeMessage();
      var rendered = message.renderMessage();
      //print(rendered);
      var parsed = MimeMessage()..bodyRaw = rendered;
      expect(parsed.getHeaderContentType().mediaType.sub,
          MediaSubtype.multipartMixed);
      expect(parsed.parts, isNotNull);
      expect(parsed.parts.length, 2);
      expect(parsed.parts[0].getHeaderContentType().mediaType.sub,
          MediaSubtype.textPlain);
      expect(parsed.parts[0].decodeContentText(), 'Hello world!\r\n');
      expect(parsed.parts[1].getHeaderContentType().mediaType.sub,
          MediaSubtype.imageJpeg);
      var disposition = parsed.parts[1].getHeaderContentDisposition();
      expect(disposition, isNotNull);
      expect(disposition.disposition, ContentDisposition.attachment);
      var decoded = parsed.parts[1].decodeContentBinary();
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
  });

  group('Content type', () {
    test('MultiPart', () {
      var builder = MessageBuilder();
      builder.from = [MailAddress('personalName', 'someone@domain.com')];
      builder
          .setContentType(MediaType.fromSubtype(MediaSubtype.multipartMixed));
      var message = builder.buildMimeMessage();
      expect(message.multiPartBoundary, isNotNull);
      var contentType = message.getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType.mediaType.top, MediaToptype.multipart);
      expect(contentType.mediaType.sub, MediaSubtype.multipartMixed);
      //print(message.renderMessage());
    });
  });
}
