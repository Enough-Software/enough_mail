import 'package:test/test.dart';
import 'package:enough_mail/mime_message.dart';

void main() {
  group('content type tests', () {
    test('content-type parsing 1', () {
      var contentTypeValue = 'text/html; charset=ISO-8859-1';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType, 'text/html');
      expect(type.topLevelType, 'text');
      expect(type.subtype, 'html');
      expect(type.charset, 'iso-8859-1');
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-1');
    });

    test('content-type parsing 2', () {
      var contentTypeValue = 'text/plain; charset="UTF-8"';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType, 'text/plain');
      expect(type.topLevelType, 'text');
      expect(type.subtype, 'plain');
      expect(type.charset, 'utf-8');
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], '"UTF-8"');
    });

    test('content-type parsing 3', () {
      var contentTypeValue =
          'multipart/alternative; boundary=bcaec520ea5d6918e204a8cea3b4';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType, 'multipart/alternative');
      expect(type.topLevelType, 'multipart');
      expect(type.subtype, 'alternative');
      expect(type.charset, isNull);
      expect(type.boundary, 'bcaec520ea5d6918e204a8cea3b4');
      expect(type.elements, isNotNull);
      expect(type.elements['boundary'], 'bcaec520ea5d6918e204a8cea3b4');
    });

    test('content-type parsing 4', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format=flowed';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType, 'text/plain');
      expect(type.topLevelType, 'text');
      expect(type.subtype, 'plain');
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
      expect(type.mediaType, 'text/plain');
      expect(type.topLevelType, 'text');
      expect(type.subtype, 'plain');
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
      var contentTypeHeader = message.getHeaderContentType();
      expect(contentTypeHeader, isNotNull);
      expect(contentTypeHeader.topLevelType, 'multipart');
      expect(contentTypeHeader.subtype, 'alternative');
      expect(contentTypeHeader.charset, isNull);
      expect(contentTypeHeader.boundary, 'unique-boundary-1');
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts.length, 3);
      expect(message.parts[0].text.trim(), 'hello COI world!');
      contentTypeHeader = message.parts[0].getHeaderContentType();
      expect(contentTypeHeader, isNotNull);
      expect(contentTypeHeader.topLevelType, 'text');
      expect(contentTypeHeader.subtype, 'plain');
      expect(contentTypeHeader.charset, 'utf-8');
      expect(message.parts[1].parts, isNotNull);
      expect(message.parts[1].parts.length, 2);
      expect(message.parts[1].parts[0].text.trim(),
          '<p>hello <b>COI</b> world!</p>');
      expect(message.parts[1].parts[1].text.trim(),
          '<p><i>This message is a chat message - consider using <a href="https://myawesomecoiapp.com">my awesome COI app</a> for best experience!</i></p>');
      expect(message.parts[2].text.trim(), 'hello **COI** world!');
    });

    test('multipart example rfc2046 section 5.1.1', () {
      var body = '''
From: Nathaniel Borenstein <nsb@bellcore.com>\r
To: Ned Freed <ned@innosoft.com>\r
Date: Sun, 21 Mar 1993 23:56:48 -0800 (PST)\r
Subject: Sample message\r
MIME-Version: 1.0\r
Content-type: multipart/mixed; boundary="simple boundary"\r
\r
This is the preamble.  It is to be ignored, though it\r
is a handy place for composition agents to include an\r
explanatory note to non-MIME conformant readers.\r
\r
--simple boundary\r
\r
This is implicitly typed plain US-ASCII text.\r
It does NOT end with a linebreak.\r
--simple boundary\r
Content-type: text/plain; charset=us-ascii\r
\r
This is explicitly typed plain US-ASCII text.\r
It DOES end with a linebreak.\r
\r
--simple boundary--\r
\r
This is the epilogue.  It is also to be ignored.\r
''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts.length, 2);
      expect(message.parts[0].headers?.isEmpty, isTrue);
      expect(message.parts[0].decodeContentText(), 'This is implicitly typed plain US-ASCII text.\r\nIt does NOT end with a linebreak.\r\n');
      expect(message.parts[0].text, 'This is implicitly typed plain US-ASCII text.\r\nIt does NOT end with a linebreak.\r\n');
      expect(message.parts[1].headers?.isNotEmpty, isTrue);
      expect(message.parts[1].headers.length, 1);
      var contentType = message.parts[1].getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType.topLevelType, 'text');
      expect(contentType.subtype, 'plain');
      expect(contentType.charset, 'us-ascii');
      expect(message.parts[1].decodeContentText(), 'This is explicitly typed plain US-ASCII text.\r\nIt DOES end with a linebreak.\r\n\r\n');
    });

    test('complex multipart example from rfc2049 appendix A', () {
      var body =
'''
MIME-Version: 1.0\r
From: Nathaniel Borenstein <nsb@nsb.fv.com>\r
To: Ned Freed <ned@innosoft.com>\r
Date: Fri, 07 Oct 1994 16:15:05 -0700 (PDT)\r
Subject: A multipart example\r
Content-Type: multipart/mixed;\r
              boundary=unique-boundary-1\r
\r
This is the preamble area of a multipart message.\r
Mail readers that understand multipart format\r
should ignore this preamble.\r
\r
If you are reading this text, you might want to\r
consider changing to a mail reader that understands\r
how to properly display multipart messages.\r
\r
--unique-boundary-1\r
\r
  ... Some text appears here ...\r
\r
[Note that the blank between the boundary and the start\r
of the text in this part means no header fields were\r
given and this is text in the US-ASCII character set.\r
It could have been done with explicit typing as in the\r
next part.]\r
\r
--unique-boundary-1\r
Content-type: text/plain; charset=US-ASCII\r
\r
This could have been part of the previous part, but\r
illustrates explicit versus implicit typing of body\r
parts.\r
\r
--unique-boundary-1\r
Content-Type: multipart/parallel; boundary=unique-boundary-2\r
\r
--unique-boundary-2\r
Content-Type: audio/basic\r
Content-Transfer-Encoding: base64\r
\r
  ... base64-encoded 8000 Hz single-channel\r
      mu-law-format audio data goes here ...\r
\r
--unique-boundary-2\r
Content-Type: image/jpeg\r
Content-Transfer-Encoding: base64\r
\r
  ... base64-encoded image data goes here ...\r
\r
--unique-boundary-2--\r
\r
--unique-boundary-1\r
Content-type: text/enriched\r
\r
This is <bold><italic>enriched.</italic></bold>\r
<smaller>as defined in RFC 1896</smaller>\r
\r
Isn't it\r
<bigger><bigger>cool?</bigger></bigger>\r
\r
--unique-boundary-1\r
Content-Type: message/rfc822\r
\r
From: (mailbox in US-ASCII)\r
To: (address in US-ASCII)\r
Subject: (subject in US-ASCII)\r
Content-Type: Text/plain; charset=ISO-8859-1\r
Content-Transfer-Encoding: Quoted-printable\r
\r
  ... Additional text in ISO-8859-1 goes here ...\r
\r
--unique-boundary-1--\r
''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts.length, 5);
      expect(message.parts[0].headers?.isEmpty, isTrue);
      var decodedContentText = message.parts[0].decodeContentText();
      expect(decodedContentText, isNotNull);
      var firstLine = decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, '  ... Some text appears here ...');
      expect(message.parts[1].headers?.isNotEmpty, isTrue);
      expect(message.parts[1].getHeaderContentType()?.mediaType, 'text/plain');
      expect(message.parts[2].getHeaderContentType()?.mediaType, 'multipart/parallel');
      expect(message.parts[2].parts, isNotNull);
      expect(message.parts[2].parts.length, 2);
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
      expect(contentType.topLevelType, 'text');
      expect(contentType.subtype, 'plain');
      expect(contentType.mediaType, 'text/plain');
      expect(contentType.charset, 'iso-8859-1');
    });
  });
}
