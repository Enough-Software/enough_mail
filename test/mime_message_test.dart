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
      expect(message.children[1].children[0].text,
          '<p>hello <b>COI</b> world!</p>');
      expect(message.children[1].children[1].text,
          '<p><i>This message is a chat message - consider using <a href="https://myawesomecoiapp.com">my awesome COI app</a> for best experience!</i></p>');
      expect(message.children[2].text, 'hello **COI** world!');
    });
  });

  group('header tests', () {
    test('https://tools.ietf.org/html/rfc2047 example 1', () {
//
      var body = '''
From: =?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>\r
To: =?ISO-8859-1?Q?Keld_J=F8rn_Simonsen?= <keld@dkuug.dk>\r
CC: =?ISO-8859-1?Q?Andr=E9?= Pirard <PIRARD@vm1.ulg.ac.be>\r
Subject: =?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?=\r
    =?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=\r
\r
''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      var header = message.decodeHeaderMailAddressValue('from');
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'Keith Moore');
      expect(header[0].email, 'moore@cs.utk.edu');
      header = message.decodeHeaderMailAddressValue('to');
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'Keld Jørn Simonsen');
      expect(header[0].email, 'keld@dkuug.dk');
      header = message.decodeHeaderMailAddressValue('cc');
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'André Pirard');
      expect(header[0].email, 'PIRARD@vm1.ulg.ac.be');

      var rawSubject = message.getHeaderValue('subject');
      expect(rawSubject,
          '=?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?==?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=');

      var subject = message.decodeHeaderValue('subject');
      expect(subject, 'If you can read this you understand the example.');
    });

    test('https://tools.ietf.org/html/rfc2047 example 2', () {
      var body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      var header = message.decodeHeaderMailAddressValue('from');
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'Nathaniel Borenstein');
      expect(header[0].email, 'nsb@thumper.bellcore.com');
      header = message.decodeHeaderMailAddressValue('to');
      expect(header, isNotNull);
      expect(header.length, 3);
      expect(header[0].personalName, 'Greg Vaudreuil');
      expect(header[0].email, 'gvaudre@NRI.Reston.VA.US');
      expect(header[1].personalName, 'Ned Freed');
      expect(header[1].email, 'ned@innosoft.com');
      expect(header[2].personalName, 'Keith Moore');
      expect(header[2].email, 'moore@cs.utk.edu');
      var subject = message.decodeHeaderValue('subject');
      expect(subject, 'Test of new header generator');
      var contentType = message.getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType.typeBase, 'text');
      expect(contentType.typeExtension, 'plain');
      expect(contentType.typeText, 'text/plain');
      expect(contentType.charset, 'iso-8859-1');
    });
  });
}
