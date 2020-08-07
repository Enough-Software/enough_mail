import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/media_type.dart';

void main() {
  group('content type tests', () {
    test('content-type parsing 1', () {
      var contentTypeValue = 'text/html; charset=ISO-8859-1';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/html');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.textHtml);
      expect(type.charset, 'iso-8859-1');
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'ISO-8859-1');
    });

    test('content-type parsing 2', () {
      var contentTypeValue = 'text/plain; charset="UTF-8"';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/plain');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.textPlain);
      expect(type.charset, 'utf-8');
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'UTF-8');
    });

    test('content-type parsing 3', () {
      var contentTypeValue =
          'multipart/alternative; boundary=bcaec520ea5d6918e204a8cea3b4';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'multipart/alternative');
      expect(type.mediaType.top, MediaToptype.multipart);
      expect(type.mediaType.sub, MediaSubtype.multipartAlternative);
      expect(type.charset, isNull);
      expect(type.boundary, 'bcaec520ea5d6918e204a8cea3b4');
      expect(type.parameters, isNotNull);
      expect(type.parameters['boundary'], 'bcaec520ea5d6918e204a8cea3b4');
    });

    test('content-type parsing 4', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format=flowed';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/plain');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.textPlain);
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'ISO-8859-15');
      expect(type.parameters['format'], 'flowed');
    });

    test('content-type parsing 5', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format="Flowed"';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/plain');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.textPlain);
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'ISO-8859-15');
      expect(type.parameters['format'], 'Flowed');
    });

    test('content-type parsing 6 - other text', () {
      var contentTypeValue =
          'text/unsupported; charset=ISO-8859-15; format="Flowed"';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/unsupported');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.other);
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'ISO-8859-15');
      expect(type.parameters['format'], 'Flowed');
    });

    test('content-type parsing 6 - other text', () {
      var contentTypeValue =
          'augmented/reality; charset=ISO-8859-15; format="Flowed"';
      var type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'augmented/reality');
      expect(type.mediaType.top, MediaToptype.other);
      expect(type.mediaType.sub, MediaSubtype.other);
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'ISO-8859-15');
      expect(type.parameters['format'], 'Flowed');
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
      expect(contentTypeHeader.mediaType, isNotNull);
      expect(contentTypeHeader.mediaType.top, MediaToptype.multipart);
      expect(
          contentTypeHeader.mediaType.sub, MediaSubtype.multipartAlternative);
      expect(contentTypeHeader.charset, isNull);
      expect(contentTypeHeader.boundary, 'unique-boundary-1');
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts.length, 3);
      expect(message.parts[0].text.trim(), 'hello COI world!');
      contentTypeHeader = message.parts[0].getHeaderContentType();
      expect(contentTypeHeader, isNotNull);
      expect(contentTypeHeader.mediaType.top, MediaToptype.text);
      expect(contentTypeHeader.mediaType.sub, MediaSubtype.textPlain);
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
      expect(message.parts[0].decodeContentText(),
          'This is implicitly typed plain US-ASCII text.\r\nIt does NOT end with a linebreak.\r\n');
      expect(message.parts[0].text,
          'This is implicitly typed plain US-ASCII text.\r\nIt does NOT end with a linebreak.\r\n');
      expect(message.parts[1].headers?.isNotEmpty, isTrue);
      expect(message.parts[1].headers.length, 1);
      var contentType = message.parts[1].getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType.mediaType.top, MediaToptype.text);
      expect(contentType.mediaType.sub, MediaSubtype.textPlain);
      expect(contentType.charset, 'us-ascii');
      expect(message.parts[1].decodeContentText(),
          'This is explicitly typed plain US-ASCII text.\r\nIt DOES end with a linebreak.\r\n\r\n');
    });

    test('complex multipart example from rfc2049 appendix A', () {
      var body = '''
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
      var firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, '  ... Some text appears here ...');
      expect(message.parts[1].headers?.isNotEmpty, isTrue);
      expect(message.parts[1].getHeaderContentType()?.mediaType?.text,
          'text/plain');
      expect(message.parts[2].getHeaderContentType()?.mediaType?.text,
          'multipart/parallel');
      expect(message.parts[2].parts, isNotNull);
      expect(message.parts[2].parts.length, 2);
    });

    test('realworld maillist-example 1', () {
      var body = '''
Return-Path: <maillist-bounces@mailman.org>\r
Received: from mx1.domain.com ([10.20.30.1])\r
	by imap.domain.com with LMTP\r
	id 4IBOKeP/dV67PQAA3c6Kzw\r
	(envelope-from <maillist-bounces@mailman.org>); Sat, 21 Mar 2020 12:52:03 +0100\r
Received: from localhost (localhost.localdomain [127.0.0.1])\r
	by mx1.domain.com (Postfix) with ESMTP id 031456A8A0;\r
	Sat, 21 Mar 2020 12:52:03 +0100 (CET)\r
Authentication-Results: domain.com;\r
	dkim=fail reason="signature verification failed" (1024-bit key; unprotected) header.d=domain.com header.i=@domain.com header.b="ZWO+bEJO";\r
	dkim-atps=neutral\r
Received: from [127.0.0.1] (helo=localhost)\r
	by localhost with ESMTP (eXpurgate 4.11.2)\r
	(envelope-from <maillist-bounces@mailman.org>)\r
	id 5e75ffe2-5613-7f000001272a-7f0000019962-1\r
	for <multiple-recipients>; Sat, 21 Mar 2020 12:52:02 +0100\r
X-Virus-Scanned: Debian amavisd-new at \r
Received: from mx1.domain.com ([127.0.0.1])\r
	by localhost (mx1.domain.com [127.0.0.1]) (amavisd-new, port 10024)\r
	with ESMTP id Dlbmr3fEFtex; Sat, 21 Mar 2020 12:52:00 +0100 (CET)\r
Received: from lists.mailman.org (lists.mailman.org [78.47.150.134])\r
	(using TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits))\r
	(Client did not present a certificate)\r
	by mx1.domain.com (Postfix) with ESMTPS id C0AFF6A84C;\r
	Sat, 21 Mar 2020 12:51:59 +0100 (CET)\r
Authentication-Results: domain.com; dmarc=fail (p=none dis=none) header.from=domain.com\r
Authentication-Results: domain.com; spf=fail smtp.mailfrom=maillist-bounces@mailman.org\r
Received: from lists.mailman.org (localhost.localdomain [127.0.0.1])\r
	by lists.mailman.org (Postfix) with ESMTP id A6BB6662F7;\r
	Sat, 21 Mar 2020 12:51:57 +0100 (CET)\r
Received: from mx1.domain.com (mx1.domain.com [198.252.153.129])\r
	by lists.mailman.org (Postfix) with ESMTPS id 59284662F7\r
	for <mailinglistt@mailman.org>; Sat, 21 Mar 2020 09:36:35 +0100 (CET)\r
Received: from bell.domain.com (unknown [10.0.1.178])\r
	(using TLSv1 with cipher ECDHE-RSA-AES256-SHA (256/256 bits))\r
	(Client CN "*.domain.com", Issuer "Sectigo RSA Domain Validation Secure Server CA" (not verified))\r
	by mx1.domain.com (Postfix) with ESMTPS id 48kvBS5CmdzFdkQ\r
	for <mailinglistt@mailman.org>; Sat, 21 Mar 2020 01:36:32 -0700 (PDT)\r
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/simple; d=domain.com; s=squak;\r
	t=1584779792; bh=HmYvFZSHKCOKVVnMnSa/hT4hGnYoH0rnFpeFMpdfdPw=;\r
	h=From:Subject:To:Date:From;\r
	b=ZWO+bEJO78+T5/RiNpKBHMTPoqvYjQ/E/BiDrEjJA9r6elA66ZqKsQDhCrL3P60UO\r
	 cZgUds8jDBWCwQ8nEyjVB0MCZ4VeEvM0TZWKvdJNXG0QmcsnlKFbUBQAOZSDHi15KD\r
	 fF8s6XwdsBtZOHg9ZexFAhQr/inmbySL57fh55UY=\r
X-Riseup-User-ID: CB036983EADDB67FB2CA8BEBB99A6F0C1684CE1D6B8DA175C55981616B3FADFF\r
Received: from [127.0.0.1] (localhost [127.0.0.1])\r
	 by bell.domain.com (Postfix) with ESMTPSA id 48kvBS1gcQzJthb\r
	for <mailinglistt@mailman.org>; Sat, 21 Mar 2020 01:36:31 -0700 (PDT)\r
From: MoMercury <reporter@domain.com>\r
To: "coi-dev Chat Developers (ML)" <mailinglistt@mailman.org>\r
Message-ID: <3971e9bf-268f-47d0-5978-b2b44ebcf470@domain.com>\r
Date: Sat, 21 Mar 2020 09:36:29 +0100\r
MIME-Version: 1.0\r
Content-Type: multipart/mixed;\r
 boundary="------------86BEE1CE827E0503C696F61E"\r
Content-Language: de-DE\r
X-MailFrom: reporter@domain.com\r
X-Mailman-Rule-Hits: nonmember-moderation\r
X-Mailman-Rule-Misses: dmarc-mitigation; no-senders; approved; emergency; loop; banned-address; member-moderation\r
Message-ID-Hash: CFYU7VLSB2J7MM6YYBZHLKZBMX5MHPDE\r
X-Message-ID-Hash: CFYU7VLSB2J7MM6YYBZHLKZBMX5MHPDE\r
X-Mailman-Approved-At: Sat, 21 Mar 2020 12:51:54 +0100\r
X-Mailman-Version: 3.3.0\r
Precedence: list\r
Subject: [coi-dev] ffi Crash Report\r
List-Id: "discussions about and around https://coi-dev.org developments" <coi-dev.mailman.org>\r
Archived-At: <https://lists.mailman.org/hyperkitty/list/mailinglistt@mailman.org/message/CFYU7VLSB2J7MM6YYBZHLKZBMX5MHPDE/>\r
List-Archive: <https://lists.mailman.org/hyperkitty/list/mailinglistt@mailman.org/>\r
List-Help: <mailto:coi-dev-request@mailman.org?subject=help>\r
List-Post: <mailto:mailinglistt@mailman.org>\r
List-Subscribe: <mailto:coi-dev-join@mailman.org>\r
List-Unsubscribe: <mailto:coi-dev-leave@mailman.org>\r
X-purgate-ID: 151428::1584791522-00005613-69FA3901/0/0\r
X-purgate-type: clean\r
X-purgate-size: 2450\r
X-purgate: clean\r
\r
This is a multi-part message in MIME format.\r
--------------86BEE1CE827E0503C696F61E\r
Content-Type: text/plain; charset=utf-8\r
Content-Transfer-Encoding: 7bit\r
\r
hello world\r
\r
\r
\r
\r
--------------86BEE1CE827E0503C696F61E\r
Content-Type: text/plain; charset=UTF-8;\r
 name="report-ffb73289-e5ba-4b13-aa8a-57ef5eede8d9.toml"\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment;\r
 filename="report-ffb73289-e5ba-4b13-aa8a-57ef5eede8d9.toml"\r
\r
bmFtZSA9ICdkZWx0YWNoYXRfZmZpJwpvcGVyYXRpbmdfc3lzdGVtID0gJ3VuaXg6QXJjaCcK\r
Y3JhdGVfdmVyc2lvbiA9ICcxLjI3LjAnCmV4cGxhbmF0aW9uID0gJycnClBhbmljIG9jY3Vy\r
cmVkIGluIGZpbGUgJ3NyYy9saWJjb3JlL3N0ci9tb2QucnMnIGF0IGxpbmUgMjA1NQonJycK\r
bWV0aG9kID0gJ1BhbmljJwpiYWNrdHJhY2UgPSAnJycKICAgMDogICAgIDB4N2Y3YzQyMzEz\r
MjE4IC0gPHVua25vd24+CiAgIDE6ICAgICAweDdmN2M0MjMxMDAzMyAtIDx1bmtub3duPgog\r
ICAyOiAgICAgMHg3ZjdjNDI2NTdjM2MgLSA8dW5rbm93bj4KICAgMzogICAgIDB4N2Y3YzQy\r
MjcxYzQ4IC0gPHVua25vd24+CiAgIDQ6ICAgICAweDdmN2M0Mjk3YzEyOCAtIDx1bmtub3du\r
PgogICA1OiAgICAgMHg3ZjdjNDI5N2JlN2UgLSA8dW5rbm93bj4KICAgNjogICAgIDB4N2Y3\r
YzQyOTkyM2Y2IC0gPHVua25vd24+CiAgIDc6ICAgICAweDdmN2M0MjMyNTI0ZCAtIDx1bmtu\r
b3duPgogICA4OiAgICAgMHg3ZjdjNDIzMjZhNjMgLSA8dW5rbm93bj4KICAgOTogICAgIDB4\r
N2Y3YzQyNWRmN2MxIC0gPHVua25vd24+CiAgMTA6ICAgICAweDdmN2M0MjNlM2Q5NCAtIDx1\r
bmtub3duPgogIDExOiAgICAgMHg3ZjdjNDIzZDFiN2EgLSA8dW5rbm93bj4KICAxMjogICAg\r
IDB4N2Y3YzQyM2QxMWY3IC0gPHVua25vd24+CiAgMTM6ICAgICAweDdmN2M0MjU3NGNmZiAt\r
IDx1bmtub3duPgogIDE0OiAgICAgMHg3ZjdjNDIzYzI0ODIgLSA8dW5rbm93bj4KICAxNTog\r
ICAgIDB4N2Y3YzQyM2JlZGQ4IC0gPHVua25vd24+CiAgMTY6ICAgICAweDdmN2M0MjUzODg3\r
MCAtIDx1bmtub3duPgogIDE3OiAgICAgMHg3ZjdjNDIyN2M5NmUgLSBkY19wZXJmb3JtX2lt\r
YXBfZmV0Y2gKICAxODogICAgIDB4N2Y3YzQyMjY0ZTIwIC0gPHVua25vd24+CiAgMTk6ICAg\r
ICAweDdmN2M1NWIxODQ2ZiAtIHN0YXJ0X3RocmVhZAogIDIwOiAgICAgMHg3ZjdjNTFjMTkz\r
ZDMgLSBjbG9uZQogIDIxOiAgICAgICAgICAgICAgICAweDAgLSA8dW5rbm93bj4KJycnCg==\r
--------------86BEE1CE827E0503C696F61E\r
Content-Type: text/plain; charset="us-ascii"\r
MIME-Version: 1.0\r
Content-Transfer-Encoding: 7bit\r
Content-Disposition: inline\r
\r
_______________________________________________\r
coi-dev mailing list -- mailinglistt@mailman.org\r
To unsubscribe send an email to coi-dev-leave@mailman.org\r
\r
--------------86BEE1CE827E0503C696F61E--\r
\r
''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts.length, 3);
      expect(message.parts[0].headers?.isNotEmpty, isTrue);
      expect(message.parts[0].getHeaderContentType()?.mediaType?.sub,
          MediaSubtype.textPlain);
      var decodedContentText = message.parts[0].decodeContentText();
      expect(decodedContentText, isNotNull);
      var firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, 'hello world');
      expect(message.parts[1].headers?.isNotEmpty, isTrue);
      expect(message.parts[1].getHeaderContentType()?.mediaType?.text,
          'text/plain');
      expect(message.parts[1].getHeaderContentType()?.mediaType?.sub,
          MediaSubtype.textPlain);
      decodedContentText = message.parts[1].decodeContentText();
      expect(decodedContentText, isNotNull);
      expect(message.parts[2].getHeaderContentType()?.mediaType?.sub,
          MediaSubtype.textPlain);
      expect(message.parts[2].parts, isNull);
      decodedContentText = message.parts[2].decodeContentText();
      expect(decodedContentText, isNotNull);
      firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, '_______________________________________________');
    });

    test('realworld maillist-example 2', () {
      var body = '''
Return-Path: <maillist-bounces@mailman.org>\r
Received: from mx1.domain.com ([10.20.30.1])\r
	by imap.domain.com with LMTP\r
	id TAmOEPuDdl4lWgAA3c6Kzw\r
	(envelope-from <maillist-bounces@mailman.org>); Sat, 21 Mar 2020 22:15:39 +0100\r
Received: from localhost (localhost.localdomain [127.0.0.1])\r
	by mx1.domain.com (Postfix) with ESMTP id 906166A8D4;\r
	Sat, 21 Mar 2020 22:15:38 +0100 (CET)\r
Authentication-Results: domain.com;\r
	dkim=fail reason="signature verification failed" (2048-bit key; unprotected) header.d=previouslyNoEvil.com header.i=@previouslyNoEvil.com header.b="oN0X9Vdd";\r
	dkim-atps=neutral\r
Received: from [127.0.0.1] (helo=localhost)\r
	by localhost with ESMTP (eXpurgate 4.11.2)\r
	(envelope-from <maillist-bounces@mailman.org>)\r
	id 5e7683fa-5613-7f000001272a-7f0000019142-1\r
	for <multiple-recipients>; Sat, 21 Mar 2020 22:15:38 +0100\r
X-Virus-Scanned: Debian amavisd-new at \r
Received: from mx1.domain.com ([127.0.0.1])\r
	by localhost (mx1.domain.com [127.0.0.1]) (amavisd-new, port 10024)\r
	with ESMTP id P9LKNQTeIkwh; Sat, 21 Mar 2020 22:15:35 +0100 (CET)\r
Received: from lists.mailman.org (lists.mailman.org [78.47.150.134])\r
	(using TLSv1.2 with cipher ECDHE-RSA-AES256-GCM-SHA384 (256/256 bits))\r
	(Client did not present a certificate)\r
	by mx1.domain.com (Postfix) with ESMTPS id 4E4B06A853;\r
	Sat, 21 Mar 2020 22:15:33 +0100 (CET)\r
Authentication-Results: domain.com; dmarc=fail (p=none dis=none) header.from=previouslyNoEvil.com\r
Authentication-Results: domain.com; spf=fail smtp.mailfrom=maillist-bounces@mailman.org\r
Received: from lists.mailman.org (localhost.localdomain [127.0.0.1])\r
	by lists.mailman.org (Postfix) with ESMTP id C3938666B2;\r
	Sat, 21 Mar 2020 22:15:30 +0100 (CET)\r
Received: from mail-lj1-x236.previouslyNoEvil.com (mail-lj1-x236.previouslyNoEvil.com [IPv6:2a00:1450:4864:20::236])\r
	by lists.mailman.org (Postfix) with ESMTPS id E1CAE666B2\r
	for <mailinglistt@mailman.org>; Sat, 21 Mar 2020 22:15:26 +0100 (CET)\r
Received: by mail-lj1-x236.previouslyNoEvil.com with SMTP id w4so10324769lji.11\r
        for <mailinglistt@mailman.org>; Sat, 21 Mar 2020 14:15:26 -0700 (PDT)\r
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;\r
        d=previouslyNoEvil.com; s=20161025;\r
        h=subject:to:references:from:message-id:date:user-agent:mime-version\r
         :in-reply-to:content-transfer-encoding:content-language;\r
        bh=LZmRjRlNHLRcS5FVoR+0sUb3WG40WTa+5hYBIWyP9W8=;\r
        b=oN0X9VddQBe02B509+0YCKMeHFVNRDLCiQFlmex88163GZqT8g7f/0/UUanHS5fJSo\r
         4XGtmVBbpSolUUcK+4Pnu8QkkhkmCmkSEqHTE9kcUONsCefDkyneOZzK5M8YfmBNBHVM\r
         MunlHFBaadP5rgWG+iuMM7KqG9Ln3DJ3WXHqTwxjMySheiVBRkVv/jD72kaqTqHd/Rx8\r
         9EE5nhxZbVuXLDc+M9FS0S5TLB4KdVtITS13z2vDQY5kjZAd1eMM6g7W3ybokZ+43VfC\r
         z4GIzYDECXKfRQpQf5JZjMOSWBYycCFx72ojkltBf2TeBokC47c93+SiAmgvEm92ohfX\r
         fklw==\r
X-Google-DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;\r
        d=1e100.net; s=20161025;\r
        h=x-gm-message-state:subject:to:references:from:message-id:date\r
         :user-agent:mime-version:in-reply-to:content-transfer-encoding\r
         :content-language;\r
        bh=LZmRjRlNHLRcS5FVoR+0sUb3WG40WTa+5hYBIWyP9W8=;\r
        b=BJAddXQjaDDQRJC/g+uXPLfRv4xCT3MLAk16JK+8DI0//FbLC7IVkbgqvfCOcmRn5q\r
         e1W8UFJzE949Q5G/NM5LnVPoa31/BEBB2nVqpUgrJayf/HYbZdHdUK9y8Dpv4fP8xXOE\r
         diLKMnjAprg4joEFOPNGy2MjHXWOFlpRjypite9r8GmrVOC8iyTwBpyy6ABUZXH1s231\r
         nIgjcHhjLWlNr2IejTHVfgf2IMntt+ReRfub+8+X1U28IZvFMTNpYCtTHjrUv+J6S1BN\r
         BpqgwvUF++dEvY2MiUi+XSNxPVIzQ4x42pzgj72Clct04k9Vy0xgLG4M7rfuxHE/5U0A\r
         gbzA==\r
X-Gm-Message-State: ANhLgQ3HZTaH97hknNii3AeUxpcap545C0INIo4iUYuhvPGpQPpXlImc\r
	sBtHvKiTLj+HDYHIFhnUxtnXHf9r\r
X-Google-Smtp-Source: ADFU+vuQQhJaAe+pMd1Nn7Os7/RHK1A6V1CC7p8hm+FXDznWO2KUE0voPM9TPCJDNIlj8ZzJlEYizA==\r
X-Received: by 2002:a2e:7e0a:: with SMTP id z10mr9164061ljc.42.1584825324994;\r
        Sat, 21 Mar 2020 14:15:24 -0700 (PDT)\r
Received: from [10.64.227.58] ([185.245.84.124])\r
        by smtp.previouslyNoEvil.com with ESMTPSA id k1sm5932121lji.43.2020.03.21.14.15.23\r
        for <mailinglistt@mailman.org>\r
        (version=TLS1_3 cipher=TLS_AES_128_GCM_SHA256 bits=128/128);\r
        Sat, 21 Mar 2020 14:15:24 -0700 (PDT)\r
To: mailinglistt@mailman.org\r
References: <3971e9bf-268f-47d0-5978-b2b44ebcf470@domain.com>\r
From: Alexander <abc@previouslyNoEvil.com>\r
Message-ID: <1ac969a2-b175-ef3a-a3c8-b9dbc93811f7@previouslyNoEvil.com>\r
Date: Sun, 22 Mar 2020 00:17:46 +0300\r
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:68.0) Gecko/20100101\r
 Thunderbird/68.6.0\r
MIME-Version: 1.0\r
In-Reply-To: <3971e9bf-268f-47d0-5978-b2b44ebcf470@domain.com>\r
Content-Language: en-US\r
Message-ID-Hash: U5WVNW4Y2AAPID373PV3AX5X4O5ZZ725\r
X-Message-ID-Hash: U5WVNW4Y2AAPID373PV3AX5X4O5ZZ725\r
X-MailFrom: abc@previouslyNoEvil.com\r
X-Mailman-Rule-Misses: dmarc-mitigation; no-senders; approved; emergency; loop; banned-address; member-moderation; nonmember-moderation; administrivia; implicit-dest; max-recipients; max-size; news-moderation; no-subject; suspicious-header\r
X-Mailman-Version: 3.3.0\r
Precedence: list\r
Subject: [coi-dev] Re: ffi Crash Report\r
List-Id: "discussions about and around https://coi-dev.org developments" <coi-dev.mailman.org>\r
Archived-At: <https://lists.mailman.org/hyperkitty/list/mailinglistt@mailman.org/message/U5WVNW4Y2AAPID373PV3AX5X4O5ZZ725/>\r
List-Archive: <https://lists.mailman.org/hyperkitty/list/mailinglistt@mailman.org/>\r
List-Help: <mailto:coi-dev-request@mailman.org?subject=help>\r
List-Post: <mailto:mailinglistt@mailman.org>\r
List-Subscribe: <mailto:coi-dev-join@mailman.org>\r
List-Unsubscribe: <mailto:coi-dev-leave@mailman.org>\r
Content-Type: text/plain; charset="us-ascii"\r
Content-Transfer-Encoding: 7bit\r
X-purgate-ID: 151428::1584825338-00005613-E081282F/0/0\r
X-purgate-type: clean\r
X-purgate-size: 566\r
\X-purgate: clean\r
\r
This is a reply\r
to explain and ask for details\r
_______________________________________________\r
coi-dev mailing list -- mailinglistt@mailman.org\r
To unsubscribe send an email to coi-dev-leave@mailman.org\r
''';
      var message = MimeMessage()..bodyRaw = body;
      message.parse();
      expect(message.headers, isNotNull);
      expect(message.parts, isNull);
      expect(message.getHeaderContentType()?.mediaType?.sub,
          MediaSubtype.textPlain);
      var decodedContentText = message.decodeContentText();
      expect(decodedContentText, isNotNull);
      var firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, 'This is a reply');
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
      expect(contentType.mediaType.top, MediaToptype.text);
      expect(contentType.mediaType.sub, MediaSubtype.textPlain);
      expect(contentType.charset, 'iso-8859-1');
    });
  });

  group('Header tests', () {
    test('Header.render() short line', () {
      var header = Header(
          'Content-Type', 'text/plain; charset="us-ascii"; format="flowed"');
      var buffer = StringBuffer();
      header.render(buffer);
      var text = buffer.toString().split('\r\n');
      expect(text.length, 2);
      expect(text[0],
          'Content-Type: text/plain; charset="us-ascii"; format="flowed"');
      expect(text[1], '');
    });
    test('Header.render() long line 1', () {
      var header = Header('Content-Type',
          'multipart/alternative; boundary="12345678901233456789012345678901234567"');
      var buffer = StringBuffer();
      header.render(buffer);
      var text = buffer.toString().split('\r\n');
      expect(text.length, 3);
      expect(text[0], 'Content-Type: multipart/alternative;');
      expect(text[1], '\tboundary="12345678901233456789012345678901234567"');
      expect(text[2], '');
    });

    test('Header.render() long line 2', () {
      var header = Header('Content-Type',
          'multipart/alternative;boundary="12345678901233456789012345678901234567"');
      var buffer = StringBuffer();
      header.render(buffer);
      var text = buffer.toString().split('\r\n');
      expect(text.length, 3);
      expect(text[0], 'Content-Type: multipart/alternative;');
      expect(text[1], '\tboundary="12345678901233456789012345678901234567"');
      expect(text[2], '');
    });

    test('Header.render() long line 3', () {
      var header = Header('Content-Type',
          'multipart/alternative;boundary="12345678901233456789012345678901234567"; fileName="one_two_three_four_five_six_seven.png";');
      var buffer = StringBuffer();
      header.render(buffer);
      var text = buffer.toString();
      expect(
          text,
          'Content-Type: multipart/alternative;\r\n'
          '\tboundary="12345678901233456789012345678901234567";\r\n'
          '\tfileName="one_two_three_four_five_six_seven.png";\r\n');
    });

    test('Header.render() long line without split pos', () {
      var header = Header('Content-Type',
          '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890');
      var buffer = StringBuffer();
      header.render(buffer);
      var text = buffer.toString().split('\r\n');
      expect(text.length, 4);
      expect(text[0],
          'Content-Type: 12345678901234567890123456789012345678901234567890123456789012');
      expect(text[1],
          '\t345678901234567890123456789012345678901234567890123456789012345678901234567');
      expect(text[2], '\t89012345678901234567890');
      expect(text[3], '');
    });
  });

  group('decodeSender()', () {
    test('From', () {
      var body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var mimeMessage = MimeMessage()..bodyRaw = body;
      var sender = mimeMessage.decodeSender();
      expect(sender, isNotEmpty);
      expect(sender.length, 1);
      expect(sender.first.personalName, 'Nathaniel Borenstein');
      expect(sender.first.email, 'nsb@thumper.bellcore.com');
    });

    test('Reply To', () {
      var body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
Reply-To: Mailinglist <mail@domain.com>\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var mimeMessage = MimeMessage()..bodyRaw = body;
      var sender = mimeMessage.decodeSender();
      expect(sender, isNotEmpty);
      expect(sender.length, 1);
      expect(sender.first.personalName, 'Mailinglist');
      expect(sender.first.email, 'mail@domain.com');
    });

    test('Combine Reply-To, Sender and From', () {
      var body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
Reply-To: Mailinglist <mail@domain.com>\r
Sender: "Real Sender" <sender@domain.com>\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var mimeMessage = MimeMessage()..bodyRaw = body;
      var sender = mimeMessage.decodeSender(combine: true);
      expect(sender, isNotEmpty);
      expect(sender.length, 3);
      expect(sender[0].personalName, 'Mailinglist');
      expect(sender[0].email, 'mail@domain.com');
      expect(sender[1].personalName, 'Real Sender');
      expect(sender[1].email, 'sender@domain.com');
      expect(sender[2].personalName, 'Nathaniel Borenstein');
      expect(sender[2].email, 'nsb@thumper.bellcore.com');
    });
  });

  group('isFrom()', () {
    test('From', () {
      var body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var mimeMessage = MimeMessage()..bodyRaw = body;
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
          ]),
          isTrue);
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'ns2b@thumper.bellcore.com')
          ]),
          isFalse);
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'other@thumper.bellcore.com'),
            MailAddress('Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
          ]),
          isTrue);
    });

    test('From with + Alias', () {
      var body = '''
From: Nathaniel Borenstein <nsb+alias@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var mimeMessage = MimeMessage()..bodyRaw = body;
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
          ]),
          isFalse);
      expect(
          mimeMessage.isFrom(
              [MailAddress('Nathaniel Borenstein', 'nsb@thumper.bellcore.com')],
              allowPlusAliases: true),
          isTrue);
    });

    test('Combine Reply-To, Sender and From', () {
      var body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
Reply-To: Mailinglist <mail@domain.com>\r
Sender: "Real Sender" <sender@domain.com>\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      var mimeMessage = MimeMessage()..bodyRaw = body;
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
          ]),
          isTrue);
      expect(mimeMessage.isFrom([MailAddress('Sender', 'sender@domain.com')]),
          isTrue);
      expect(mimeMessage.isFrom([MailAddress('Reply To', 'mail@domain.com')]),
          isTrue);
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'ns2b@thumper.bellcore.com')
          ]),
          isFalse);
      expect(
          mimeMessage.isFrom([
            MailAddress('Nathaniel Borenstein', 'other@thumper.bellcore.com'),
            MailAddress('Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
          ]),
          isTrue);
    });
  });

  group('ContentDispositionHeader tests', () {
    test('render()', () {
      var header = ContentDispositionHeader.from(ContentDisposition.inline);
      expect(header.render(), 'inline');
      header.filename = 'image.jpeg';
      expect(header.render(), 'inline; filename="image.jpeg"');
      var creation = DateTime.now();
      var creationDateText = DateCodec.encodeDate(creation);
      header.creationDate = creation;
      expect(header.render(),
          'inline; filename="image.jpeg"; creation-date="$creationDateText"');
      header.size = 2046;
      expect(header.render(),
          'inline; filename="image.jpeg"; creation-date="$creationDateText"; size=2046');
      header.setParameter('hello', 'world');
      expect(header.render(),
          'inline; filename="image.jpeg"; creation-date="$creationDateText"; size=2046; hello=world');
    });
  });
}
