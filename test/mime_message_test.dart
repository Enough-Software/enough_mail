import 'package:test/test.dart';
import 'package:enough_mail/mime_message.dart';

void main() {
  group('content type tests', () {
    test('content-type parsing 1', () {
      var contentTypeValue = 'text/html; charset=ISO-8859-1';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/html');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'html');
      expect(type.charset, 'iso-8859-1');
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-1');
    });

    test('content-type parsing 2', () {
      var contentTypeValue = 'text/plain; charset="UTF-8"';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/plain');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'plain');
      expect(type.charset, 'utf-8');
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], '"UTF-8"');
    });

    test('content-type parsing 3', () {
      var contentTypeValue =
          'multipart/alternative; boundary=bcaec520ea5d6918e204a8cea3b4';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'multipart/alternative');
      expect(type.typeBase, 'multipart');
      expect(type.typeExtension, 'alternative');
      expect(type.charset, isNull);
      expect(type.boundary, 'bcaec520ea5d6918e204a8cea3b4');
      expect(type.elements, isNotNull);
      expect(type.elements['boundary'], 'bcaec520ea5d6918e204a8cea3b4');
    });

    test('content-type parsing 4', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format=flowed';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/plain');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'plain');
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-15');
      expect(type.elements['format'], 'flowed');
    });

    test('content-type parsing 5', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format="Flowed"';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/plain');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'plain');
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-15');
      expect(type.elements['format'], '"Flowed"');
    });
  });

  group('parse tests', () {
    test('multipart/alternative  1', () {
      var body = '''
From: Me Myself <me@sample.com>\r
To: You <you@recipientdomain.com>\r 
Subject: \r
Date: Mon, 4 Dec 2019 15:51:37 +0100\r
Message-ID: <coi\$22938.8238702@sample.com>\r
Content-Type: multipart/alternative;\r
 boundary=unique-boundary-1\r
Reference: <coi\$434571BC.89A707D2@sample.com>\r
Chat-Version: 1.0\r
Disposition-Notification-To: Me Myself <me@sample.com>\r
MIME-Version: 1.0\r
\r
--unique-boundary-1\r
Content-Type: text/plain; charset=UTF-8\r
\r
hello COI world!\r
\r
\r
--unique-boundary-1\r
Content-Type: multipart/mixed;\r
 boundary=unique-boundary-2\r
\r
--unique-boundary-2\r
Content-Type: text/html; charset=UTF-8\r
\r
<p>hello <b>COI</b> world!</p>\r
\r
--unique-boundary-2\r
Content-Type: text/html; charset=UTF-8\r
Chat-Content: ignore\r
\r
<p><i>This message is a chat message - consider using <a href="https://myawesomecoiapp.com">my awesome COI app</a> for best experience!</i></p>\r
\r
--unique-boundary-2--\r
\r
--unique-boundary-1\r
Content-Type: text/markdown; charset=UTF-8\r
\r
hello **COI** world!\r
\r
--unique-boundary-1--\r
      ''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      expect(message.children, isNotNull);
      expect(message.children.length, 3);
      expect(message.children[0].text, 'hello COI world!');
      expect(message.children[1].children, isNotNull);
      expect(message.children[1].children.length, 2);
      expect(message.children[1].children[0].text, '<p>hello <b>COI</b> world!</p>');
      expect(message.children[1].children[1].text, '<p><i>This message is a chat message - consider using <a href="https://myawesomecoiapp.com">my awesome COI app</a> for best experience!</i></p>');
      expect(message.children[2].text, 'hello **COI** world!');
    });
  });
}
