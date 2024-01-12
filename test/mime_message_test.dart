import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_convert/enough_convert.dart';
import 'package:enough_mail/src/codecs/date_codec.dart';
import 'package:enough_mail/src/codecs/mail_codec.dart';
import 'package:enough_mail/src/mail_address.dart';
import 'package:enough_mail/src/media_type.dart';
import 'package:enough_mail/src/mime_message.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  group('content type tests', () {
    test('content-type parsing 1', () {
      const contentTypeValue = 'text/HTML; charset=ISO-8859-1';
      final type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/html');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.textHtml);
      expect(type.charset, 'iso-8859-1');
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'ISO-8859-1');
    });

    test('content-type parsing 2', () {
      const contentTypeValue = 'text/plain; charset="UTF-8"';
      final type = ContentTypeHeader(contentTypeValue);
      expect(type, isNotNull);
      expect(type.mediaType.text, 'text/plain');
      expect(type.mediaType.top, MediaToptype.text);
      expect(type.mediaType.sub, MediaSubtype.textPlain);
      expect(type.charset, 'utf-8');
      expect(type.parameters, isNotNull);
      expect(type.parameters['charset'], 'UTF-8');
    });

    test('content-type parsing 3', () {
      const contentTypeValue =
          'multipart/alternative; boundary=bcaec520ea5d6918e204a8cea3b4';
      final type = ContentTypeHeader(contentTypeValue);
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
      const contentTypeValue = 'TEXT/PLAIN; charset=ISO-8859-15; format=flowed';
      final type = ContentTypeHeader(contentTypeValue);
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
      const contentTypeValue =
          'text/plain; charset=ISO-8859-15; format="Flowed"';
      final type = ContentTypeHeader(contentTypeValue);
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
      const contentTypeValue =
          'text/unsupported; charset=ISO-8859-15; format="Flowed"';
      final type = ContentTypeHeader(contentTypeValue);
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
      const contentTypeValue =
          'augmented/reality; charset=ISO-8859-15; format="Flowed"';
      final type = ContentTypeHeader(contentTypeValue);
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
      const body = '''
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
      final message = MimeMessage.parseFromText(body);
      var contentTypeHeader = message.getHeaderContentType();
      expect(contentTypeHeader, isNotNull);
      expect(contentTypeHeader!.mediaType, isNotNull);
      expect(contentTypeHeader.mediaType.top, MediaToptype.multipart);
      expect(
          contentTypeHeader.mediaType.sub, MediaSubtype.multipartAlternative);
      expect(contentTypeHeader.charset, isNull);
      expect(contentTypeHeader.boundary, 'unique-boundary-1');
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts!.length, 3);
      expect(message.decodeTextPlainPart()!.trim(), 'hello COI world!');
      contentTypeHeader = message.parts![0].getHeaderContentType()!;
      expect(contentTypeHeader, isNotNull);
      expect(contentTypeHeader.mediaType.top, MediaToptype.text);
      expect(contentTypeHeader.mediaType.sub, MediaSubtype.textPlain);
      expect(contentTypeHeader.charset, 'utf-8');
      expect(message.parts![1].parts, isNotNull);
      expect(message.parts![1].parts!.length, 2);
      expect(message.parts![1].parts![0].decodeContentText()!.trim(),
          '<p>hello <b>COI</b> world!</p>');
      expect(message.parts![1].parts![1].decodeContentText()!.trim(),
          '<p><i>This message is a chat message - consider using <a href="https://myawesomecoiapp.com">my awesome COI app</a> for best experience!</i></p>');
      expect(message.parts![2].decodeContentText()!.trim(),
          'hello **COI** world!');
      expect(message.isTextPlainMessage(), isTrue);
    });

    test('multipart example rfc2046 section 5.1.1', () {
      const body = '''
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
      final message = MimeMessage.parseFromText(body);
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts!.length, 2);
      expect(message.parts![0].headers, isNull);
      expect(
          message.parts![0].decodeContentText(),
          'This is implicitly typed plain US-ASCII text.\r\n'
          'It does NOT end with a linebreak.\r\n');
      expect(
          message.parts![0].decodeContentText(),
          'This is implicitly typed plain US-ASCII text.\r\nIt does NOT end '
          'with a linebreak.\r\n');
      expect(message.parts![1].headers?.isNotEmpty, isTrue);
      expect(message.parts![1].headers!.length, 1);
      final contentType = message.parts![1].getHeaderContentType()!;
      expect(contentType, isNotNull);
      expect(contentType.mediaType.top, MediaToptype.text);
      expect(contentType.mediaType.sub, MediaSubtype.textPlain);
      expect(contentType.charset, 'us-ascii');
      expect(
          message.parts![1].decodeContentText(),
          'This is explicitly typed plain US-ASCII text.\r\n'
          'It DOES end with a linebreak.\r\n\r\n');
      expect(message.isTextPlainMessage(), isTrue);
    });

    test('complex multipart example from rfc2049 appendix A', () {
      const body = '''
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
      final message = MimeMessage.parseFromText(body);
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts!.length, 5);
      expect(message.parts![0].headers, isNull);
      final decodedContentText = message.parts![0].decodeContentText()!;
      expect(decodedContentText, isNotNull);
      final firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, '  ... Some text appears here ...');
      expect(message.parts![1].headers?.isNotEmpty, isTrue);
      expect(message.parts![1].getHeaderContentType()?.mediaType.text,
          'text/plain');
      expect(message.parts![2].getHeaderContentType()?.mediaType.text,
          'multipart/parallel');
      expect(message.parts![2].parts, isNotNull);
      expect(message.parts![2].parts!.length, 2);
    });

    test('realworld maillist-example 1', () {
      const body = '''
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
      final message = MimeMessage.parseFromText(body)..parse();
      expect(message.headers, isNotNull);
      expect(message.parts, isNotNull);
      expect(message.parts!.length, 3);
      expect(message.parts![0].headers?.isNotEmpty, isTrue);
      expect(message.parts![0].getHeaderContentType()?.mediaType.sub,
          MediaSubtype.textPlain);
      var decodedContentText = message.parts![0].decodeContentText()!;
      expect(decodedContentText, isNotNull);
      var firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, 'hello world');
      expect(message.parts![1].headers?.isNotEmpty, isTrue);
      expect(message.parts![1].getHeaderContentType()?.mediaType.text,
          'text/plain');
      expect(message.parts![1].getHeaderContentType()?.mediaType.sub,
          MediaSubtype.textPlain);
      decodedContentText = message.parts![1].decodeContentText()!;
      expect(decodedContentText, isNotNull);
      expect(message.parts![2].getHeaderContentType()?.mediaType.sub,
          MediaSubtype.textPlain);
      expect(message.parts![2].parts, isNull);
      decodedContentText = message.parts![2].decodeContentText()!;
      expect(decodedContentText, isNotNull);
      firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, '_______________________________________________');
    });

    test('realworld maillist-example 2', () {
      const body = '''
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
      final message = MimeMessage.parseFromText(body);
      expect(message.headers, isNotNull);
      expect(message.parts, isNull);
      expect(message.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.textPlain);
      final decodedContentText = message.decodeContentText()!;
      expect(decodedContentText, isNotNull);
      final firstLine =
          decodedContentText.substring(0, decodedContentText.indexOf('\r\n'));
      expect(firstLine, 'This is a reply');
    });

    test('Realworld PGP Message Test', () {
      const body = '''
From: sender@domain.com\r
To: receiver@domain.com\r
Message-ID: <05fb895f-e6e8-4e40-fc9e-1a86a2b7ac55@xxxxxxxx.org>\r
Subject: Re: XXXXXX\r
References: <66704825-5855-4783-b7c3-d48ee34c46d8@xxxxx.re>\r
In-Reply-To: <66704825-5855-4783-b7c3-d48ee34c46d8@xxxxxx.re>\r
Date: Sun, 8 Nov 2020 00:17:46 +0300\r
Content-Type: multipart/signed; boundary="jsRvMCvIu46WpNX1JGpxzIxzfAm6xTTQ6";\r
\r
This is an OpenPGP/MIME signed message (RFC 4880 and 3156)\r
--jsRvMCvIu46WpNX1JGpxzIxzfAm6xTTQ6\r
Content-Type: multipart/mixed; boundary="BHExnvuVOviQxAIGaEirfgZbVhPGKVh6z";\r
 protected-headers="v1"\r
From: =?UTF-8?Q?XXXXXXX_XXXXXX?= <xxxxxxx@xxxxxxx.org>\r
To: Xxxxxxx <xxxxx@xxxxx.re>\r
Message-ID: <05fb895f-e6e8-4e40-fc9e-1a86a2b7ac55@xxxxxxxx.org>\r
Subject: Re: XXXXXX\r
References: <66704825-5855-4783-b7c3-d48ee34c46d8@xxxxx.re>\r
In-Reply-To: <66704825-5855-4783-b7c3-d48ee34c46d8@xxxxxx.re>\r
\r
--BHExnvuVOviQxAIGaEirfgZbVhPGKVh6z\r
Content-Type: multipart/mixed;\r
 boundary="------------831B4B68BAC422FAB7101CF9"\r
\r
This is a multi-part message in MIME format.\r
--------------831B4B68BAC422FAB7101CF9\r
Content-Type: multipart/alternative;\r
 boundary="------------E7938C4510EDF90BE5C237F5"\r
\r
\r
--------------E7938C4510EDF90BE5C237F5\r
Content-Type: text/plain; charset=utf-8; format=flowed\r
Content-Transfer-Encoding: quoted-printable\r
\r
THE MESSAGE TEXT....\r
Regards\r
.....\r
\r
Am 01.11.2020 um 18:30 schrieb XXXXXX:\r
> A quote\r
\r
--------------E7938C4510EDF90BE5C237F5\r
Content-Type: text/html; charset=utf-8\r
Content-Transfer-Encoding: quoted-printable\r
\r
<html>\r
  <head>\r
    <meta http-equiv=3D"Content-Type" content=3D"text/html; charset=3DUTF=\r
-8">\r
  </head>\r
  <body>\r
    <p>XXXXX, <br>\r
    </p>\r
    <p>SOME HTML\r
    </p>\r
    <div class=3D"moz-cite-prefix">Am 01.11.2020 um 18:30 schrieb XXXXXXX:<=\r
br>\r
    </div>\r
    <blockquote type=3D"cite"\r
      cite=3D"mid:66704825-5855-4783-b7c3-d48ee34c46d8@xxxxxx.re">\r
      <meta http-equiv=3D"content-type" content=3D"text/html; charset=3DU=\r
TF-8">\r
SOME HTML\r
    </blockquote>\r
  </body>\r
</html>\r
\r
--------------E7938C4510EDF90BE5C237F5--\r
\r
--------------831B4B68BAC422FAB7101CF9\r
Content-Type: application/pgp-keys;\r
 name="OpenPGP_0xXXXXXXXXX.asc"\r
Content-Transfer-Encoding: quoted-printable\r
Content-Disposition: attachment;\r
 filename="OpenPGP_0xXXXXXXXXX.asc"\r
\r
-----BEGIN PGP PUBLIC KEY BLOCK-----\r
\r
[...]\r
ALkh8XOCbFCWAP9OpfmHxIuwbmK6yNuoQhygxjqh4gcuE3nrJYYbt8/vAw=3D=3D\r
=3DLyed\r
-----END PGP PUBLIC KEY BLOCK-----\r
\r
--------------831B4B68BAC422FAB7101CF9--\r
\r
--BHExnvuVOviQxAIGaEirfgZbVhPGKVh6z--\r
\r
--jsRvMCvIu46WpNX1JGpxzIxzfAm6xTTQ6\r
Content-Type: application/pgp-signature; name="OpenPGP_signature.asc"\r
Content-Description: OpenPGP digital signature\r
Content-Disposition: attachment; filename="OpenPGP_signature"\r
\r
-----BEGIN PGP SIGNATURE-----\r
\r
wnsEABYIACMWIQS\r
[...]\r
b6oUGuLbJCwEAmL28F+QOf1nLe3ABYV1J/6aTDZir\r
UckHnSueOzINHwA=\r
=bNL9\r
-----END PGP SIGNATURE-----\r
\r
--jsRvMCvIu46WpNX1JGpxzIxzfAm6xTTQ6--\r
      ''';
      final message = MimeMessage.parseFromText(body);
      expect(message.headers, isNotNull);
      expect(message.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.multipartSigned);
      expect(message.parts, isNotNull);
      expect(message.allPartsFlat, isNotNull);
      expect(message.allPartsFlat, isNotEmpty);
      final keysPart = message.allPartsFlat.firstWhereOrNull((part) =>
          part.getHeaderContentType()?.mediaType.sub ==
          MediaSubtype.applicationPgpKeys);
      expect(keysPart, isNotNull);
      expect(message.allPartsFlat.last.getHeaderContentType()?.mediaType.sub,
          MediaSubtype.applicationPgpSignature);
    });
  });

  group('header tests', () {
    test('https://tools.ietf.org/html/rfc2047 example 1', () {
//
      const body = '''
From: =?US-ASCII?Q?Keith_Moore?= <moore@cs.utk.edu>\r
To: =?ISO-8859-1?Q?Keld_J=F8rn_Simonsen?= <keld@dkuug.dk>\r
CC: =?ISO-8859-1?Q?Andr=E9?= Pirard <PIRARD@vm1.ulg.ac.be>\r
Subject: =?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?=\r
    =?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=\r
\r
''';
      final message = MimeMessage.parseFromText(body);
      expect(message.headers, isNotNull);
      var header = message.decodeHeaderMailAddressValue('from')!;
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'Keith Moore');
      expect(header[0].email, 'moore@cs.utk.edu');
      header = message.decodeHeaderMailAddressValue('to')!;
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'Keld Jørn Simonsen');
      expect(header[0].email, 'keld@dkuug.dk');
      header = message.decodeHeaderMailAddressValue('cc')!;
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'André Pirard');
      expect(header[0].email, 'PIRARD@vm1.ulg.ac.be');

      final rawSubject = message.getHeaderValue('subject');
      expect(
          rawSubject,
          '=?ISO-8859-1?B?SWYgeW91IGNhbiByZWFkIHRoaXMgeW8=?='
          '=?ISO-8859-2?B?dSB1bmRlcnN0YW5kIHRoZSBleGFtcGxlLg==?=');

      final subject = message.decodeHeaderValue('subject');
      expect(subject, 'If you can read this you understand the example.');
    });

    test('https://tools.ietf.org/html/rfc2047 example 2', () {
      const body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      final message = MimeMessage.parseFromText(body);
      expect(message.headers, isNotNull);
      var header = message.decodeHeaderMailAddressValue('from')!;
      expect(header, isNotNull);
      expect(header.length, 1);
      expect(header[0].personalName, 'Nathaniel Borenstein');
      expect(header[0].email, 'nsb@thumper.bellcore.com');
      header = message.decodeHeaderMailAddressValue('to')!;
      expect(header, isNotNull);
      expect(header.length, 3);
      expect(header[0].personalName, 'Greg Vaudreuil');
      expect(header[0].email, 'gvaudre@NRI.Reston.VA.US');
      expect(header[1].personalName, 'Ned Freed');
      expect(header[1].email, 'ned@innosoft.com');
      expect(header[2].personalName, 'Keith Moore');
      expect(header[2].email, 'moore@cs.utk.edu');
      final subject = message.decodeHeaderValue('subject');
      expect(subject, 'Test of new header generator');
      final contentType = message.getHeaderContentType();
      expect(contentType, isNotNull);
      expect(contentType!.mediaType.top, MediaToptype.text);
      expect(contentType.mediaType.sub, MediaSubtype.textPlain);
      expect(contentType.charset, 'iso-8859-1');
    });
  });

  group('Header tests', () {
    test('Header.render() short line', () {
      final header = Header(
          'Content-Type', 'text/plain; charset="us-ascii"; format="flowed"');
      final buffer = StringBuffer();
      header.render(buffer);
      final text = buffer.toString().split('\r\n');
      expect(text.length, 2);
      expect(text[0],
          'Content-Type: text/plain; charset="us-ascii"; format="flowed"');
      expect(text[1], '');
    });
    test('Header.render() long line 1', () {
      final header = Header('Content-Type',
          'multipart/alternative; boundary="12345678901233456789012345678901234567"');
      final buffer = StringBuffer();
      header.render(buffer);
      final text = buffer.toString().split('\r\n');
      expect(text.length, 3);
      expect(text[0], 'Content-Type: multipart/alternative;');
      expect(text[1], '\tboundary="12345678901233456789012345678901234567"');
      expect(text[2], '');
    });

    test('Header.render() long line 2', () {
      final header = Header('Content-Type',
          'multipart/alternative;boundary="12345678901233456789012345678901234567"');
      final buffer = StringBuffer();
      header.render(buffer);
      final text = buffer.toString().split('\r\n');
      expect(text.length, 3);
      expect(text[0], 'Content-Type: multipart/alternative;');
      expect(text[1], '\tboundary="12345678901233456789012345678901234567"');
      expect(text[2], '');
    });

    test('Header.render() long line 3', () {
      final header = Header('Content-Type',
          'multipart/alternative;boundary="12345678901233456789012345678901234567"; fileName="one_two_three_four_five_six_seven.png";');
      final buffer = StringBuffer();
      header.render(buffer);
      final text = buffer.toString();
      expect(
          text,
          'Content-Type: multipart/alternative;\r\n'
          '\tboundary="12345678901233456789012345678901234567";\r\n'
          '\tfileName="one_two_three_four_five_six_seven.png";\r\n');
    });

    test('Header.render() long line without split pos', () {
      final header = Header(
          'Content-Type',
          '1234567890123456789012345678901234567890123456789012345678901234'
              '5678901234567890123456789012345678901234567890123456789012345678'
              '90123456789012345678901234567890');
      final buffer = StringBuffer();
      header.render(buffer);
      final text = buffer.toString().split('\r\n');
      expect(text.length, 4);
      expect(
          text[0],
          'Content-Type: 123456789012345678901234567890123456789012345678901'
          '23456789012');
      expect(
          text[1],
          '\t345678901234567890123456789012345678901234567890123456789012345'
          '678901234567');
      expect(text[2], '\t89012345678901234567890');
      expect(text[3], '');
    });
  });

  group('decodeSender()', () {
    test('From', () {
      const body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      final mimeMessage = MimeMessage.parseFromText(body);
      final sender = mimeMessage.decodeSender();
      expect(sender, isNotEmpty);
      expect(sender.length, 1);
      expect(sender.first.personalName, 'Nathaniel Borenstein');
      expect(sender.first.email, 'nsb@thumper.bellcore.com');
    });

    test('Reply To', () {
      const body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
Reply-To: Mailinglist <mail@domain.com>\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      final mimeMessage = MimeMessage.parseFromText(body);
      final sender = mimeMessage.decodeSender();
      expect(sender, isNotEmpty);
      expect(sender.length, 1);
      expect(sender.first.personalName, 'Mailinglist');
      expect(sender.first.email, 'mail@domain.com');
    });

    test('Combine Reply-To, Sender and From', () {
      const body = '''
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
      final mimeMessage = MimeMessage.parseFromText(body);
      final sender = mimeMessage.decodeSender(combine: true);
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
      const body = '''
From: Nathaniel Borenstein <nsb@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      final mimeMessage = MimeMessage.parseFromText(body);
      expect(
          mimeMessage.isFrom(const MailAddress(
              'Nathaniel Borenstein', 'nsb@thumper.bellcore.com')),
          isTrue);
      expect(
          mimeMessage.isFrom(const MailAddress(
              'Nathaniel Borenstein', 'ns2b@thumper.bellcore.com')),
          isFalse);
      expect(
          mimeMessage.isFrom(
              const MailAddress(
                  'Nathaniel Borenstein', 'other@thumper.bellcore.com'),
              aliases: [
                const MailAddress(
                    'Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
              ]),
          isTrue);
    });

    test('From with + Alias', () {
      const body = '''
From: Nathaniel Borenstein <nsb+alias@thumper.bellcore.com>\r
    (=?iso-8859-8?b?7eXs+SDv4SDp7Oj08A==?=)\r
To: Greg Vaudreuil <gvaudre@NRI.Reston.VA.US>, Ned Freed\r
  <ned@innosoft.com>, Keith Moore <moore@cs.utk.edu>\r
Subject: Test of new header generator\r
MIME-Version: 1.0\r
Content-type: text/plain; charset=ISO-8859-1\r
''';
      final mimeMessage = MimeMessage.parseFromText(body);
      expect(
          mimeMessage.isFrom(const MailAddress(
              'Nathaniel Borenstein', 'nsb@thumper.bellcore.com')),
          isFalse);
      expect(
          mimeMessage.isFrom(
              const MailAddress(
                  'Nathaniel Borenstein', 'nsb@thumper.bellcore.com'),
              allowPlusAliases: true),
          isTrue);
    });

    test('Combine Reply-To, Sender and From', () {
      const body = '''
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
      final mimeMessage = MimeMessage.parseFromText(body);
      expect(
          mimeMessage.isFrom(const MailAddress(
              'Nathaniel Borenstein', 'nsb@thumper.bellcore.com')),
          isTrue);
      expect(
          mimeMessage.isFrom(const MailAddress('Sender', 'sender@domain.com')),
          isTrue);
      expect(
          mimeMessage.isFrom(const MailAddress('Reply To', 'mail@domain.com')),
          isTrue);
      expect(
          mimeMessage.isFrom(const MailAddress(
              'Nathaniel Borenstein', 'ns2b@thumper.bellcore.com')),
          isFalse);
      expect(
          mimeMessage.isFrom(
              const MailAddress(
                  'Nathaniel Borenstein', 'other@thumper.bellcore.com'),
              aliases: [
                const MailAddress(
                    'Nathaniel Borenstein', 'nsb@thumper.bellcore.com')
              ]),
          isTrue);
    });
  });

  group('ContentDispositionHeader tests', () {
    test('render()', () {
      final header = ContentDispositionHeader.from(ContentDisposition.inline);
      expect(header.render(), 'inline');
      header.filename = 'image.jpeg';
      expect(header.render(), 'inline; filename="image.jpeg"');
      final creation = DateTime.now();
      final creationDateText = DateCodec.encodeDate(creation);
      header.creationDate = creation;
      expect(header.render(),
          'inline; filename="image.jpeg"; creation-date="$creationDateText"');
      header.size = 2046;
      expect(
          header.render(),
          'inline; filename="image.jpeg"; creation-date="$creationDateText";'
          ' size=2046');
      header.setParameter('hello', 'world');
      expect(
          header.render(),
          'inline; filename="image.jpeg"; creation-date="$creationDateText";'
          ' size=2046; hello=world');
    });

    test('listContentInfo() 1', () {
      const body = '''
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
      final message = MimeMessage.parseFromText(body);
      var attachments = message.findContentInfo();
      expect(attachments, isNotEmpty);
      expect(attachments.length, 1);
      expect(attachments[0].contentDisposition!.filename,
          'report-ffb73289-e5ba-4b13-aa8a-57ef5eede8d9.toml');
      expect(attachments[0].contentType!.mediaType.sub, MediaSubtype.textPlain);

      attachments =
          message.findContentInfo(disposition: ContentDisposition.attachment);
      expect(attachments, isNotEmpty);
      expect(attachments.length, 1);
      expect(attachments[0].contentDisposition!.filename,
          'report-ffb73289-e5ba-4b13-aa8a-57ef5eede8d9.toml');
      expect(attachments[0].contentType!.mediaType.sub, MediaSubtype.textPlain);

      final inlineAttachments =
          message.findContentInfo(disposition: ContentDisposition.inline);
      expect(inlineAttachments, isNotEmpty);
      expect(inlineAttachments.length, 1);
      expect(inlineAttachments[0].contentType!.mediaType.sub,
          MediaSubtype.textPlain);
    });

    test('listContentInfo() 2', () {
      const body = '''
From: MoMercury <reporter@domain.com>\r
To: "coi-dev Chat Developers (ML)" <mailinglistt@mailman.org>\r
Message-ID: <3971e9bf-268f-47d0-5978-b2b44ebcf470@domain.com>\r
Date: Sat, 21 Mar 2020 09:36:29 +0100\r
MIME-Version: 1.0\r
Content-Type: multipart/mixed;\r
 boundary="------------86BEE1CE827E0503C696F61E"\r
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
ZDMgLSBjbG9uZQogIDIxOiAgICAgICAgICAgICAgICAweDAgLSA8dW5rbm93bj4KJycnCg==\r
--------------86BEE1CE827E0503C696F61E\r
Content-Type: image/jpg; \r
 name="hello.jpg"\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment;\r
 filename="hello.jpg"\r
\r
bmFtZSA9ICdkZWx0YWNoYXRfZmZpJwpvcGVyYXRpbmdfc3lzdGVtID0gJ3VuaXg6QXJjaCcK\r
Y3JhdGVfdmVyc2lvbiA9ICcxLjI3LjAnCmV4cGxhbmF0aW9uID0gJycnClBhbmljIG9jY3Vy\r
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
      final message = MimeMessage.parseFromText(body);
      final attachments = message.findContentInfo();
      expect(attachments, isNotEmpty);
      expect(attachments.length, 2);
      expect(attachments[0].contentDisposition!.filename,
          'report-ffb73289-e5ba-4b13-aa8a-57ef5eede8d9.toml');
      expect(attachments[0].contentType!.mediaType.sub, MediaSubtype.textPlain);

      expect(attachments[1].contentDisposition!.filename, 'hello.jpg');
      expect(attachments[1].contentType!.mediaType.sub, MediaSubtype.imageJpeg);
    });

    test('apple message with image attachment', () {
      const body = '''Return-Path: <xmonty@xxx.com>\r
X-Original-To: xxx@xxx.com\r
Delivered-To: to@xxx.com\r
Received: from mail-pf1-f179.google.com (mail-pf1-f179.xxx.com\r
 [219.185.20.19])	by mail.mymailer.com (Postfix) with ESMTP id 94EDE2B233\r
	for <xxx@xxx.com>; Tue, 13 Apr 2021 08:59:27 +0000 (UTC)\r
Received: by mail-pf1-f179.xxx.com with SMTP id i190so10995473pfc.12\r
        for <xxx@xxx.com>; Tue, 13 Apr 2021 01:59:27 -0700 (PDT)\r
DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;\r
        d=gmail.com; s=20161025;\r
        h=content-transfer-encoding:from:mime-version:date:subject:message-id\r
         :to;\r
        bh=gS2crawKAAJIL0lhrGgpMH/+SncTCQgHD0EzFvQziUs=;\r
        b=Kjk9RU9CBBlIdBXA8kIXuJhe7XHyy96OXnwSQ8m5dDhUKIlTiJjBFwI58TQFvRO6S7\r
         n/+PPZoo1MmQ4R7ZFyUjiFrxRGZTieORltFnFdR+DMND2bu/0ZHedwDmrySb3Ntn8n8K\r
         UphR0KkvV1Bg3aHmUnX8oV/Okyj5fRvUE9X/u69eJ2jVTIOQeMLlFPdfu7WbXFG7L334\r
         Aa15cDZuVzPweLbRzTxHLZnWob0eIgvw83lwDJKEn1eyprpGbcb3yLEkTvfjdQprHall\r
         arRD1xoZxNs1v17IWlsYuERKLjiB4xQ+6gWDvn+YR3F8q9Ltq2M22WsNdN7iho1WUpAM\r
         NjyA==\r
X-Google-DKIM-Signature: v=1; a=rsa-sha256; c=relaxed/relaxed;\r
        d=1e100.net; s=20161025;\r
        h=x-gm-message-state:content-transfer-encoding:from:mime-version:date\r
         :subject:message-id:to;\r
        bh=gS2crawKAAJIL0lhrGgpMH/+SncTCQgHD0EzFvQziUs=;\r
        b=INzi5r2oA2ljYMtOdL8GogLkrTgp6VGZwTvCA+0ede5Teikmq57hxr7+Eo+H1ifjp8\r
         Y8tPb667T1BziUKGxxrWtF+9+OA9jcY3dIBjvjv7LuR05MEPZmlbZxZNZ/25mExzp9tS\r
         s/IXg6B0c8wwZHcXdUt2f9gXRPAR93AhgH4dWt/q5wHESbD2yAYYxcG4oiJvuQlxZWMp\r
         Wfly3iQY48rxUHv5iEB3e351M1uuT6wJoBW62cpig1qtOXKTwasuOF0IJoIWjBHHR0L9\r
         Nk2qnD3Lx5CnJRoEtRIyTTQJZbW+goOqUaMl+6qNhWPu31eiJSiH/XrFf0tgr5Rg07zc\r
         xb8w==\r
X-Gm-Message-State: AOAM533WF/dIyilsto6awfIZI4pSOsaOUI05xiWlBMezEBKxnsee0PRl\r
	JyqpM4m/piAADkfoVfII+PkQV2EA4YmC+Q==\r
X-Google-Smtp-Source: =?utf-8?q?ABdhPJw5iY9314ApYnp58r1WeDkp/tws+5AnSGbNrSCY?=\r
 =?utf-8?q?zokPQvxrEEXt900NQk/Ri0+LFXv2IEywDw=3D=3D?=\r
X-Received: by 2002:a63:342:: with SMTP id 63mr3052e000pgd.151.1618304344742;\r
        Tue, 13 Apr 2021 01:59:26 -0700 (PDT)\r
Received: from [192.168.0.197] ([103.72.10.65])        by smtp.gmail.com with\r
 ESMTPSA id r22sm14923402pgu.81.2021.04.13.01.59.25        for\r
 <xxx@xxx.com>        (version=TLS1_3\r
 cipher=TLS_AES_128_GCM_SHA256 bits=128/128);        Tue, 13 Apr 2021 01:59:25\r
 -0700 (PDT)\r
Content-Type: multipart/mixed;
 boundary="Apple-Mail-96411171-B27C-4257-BB83-14E1DC508502"\r
Content-Transfer-Encoding: 7bit\r
From: Manoj Subberwal <xmonty@gmail.com>\r
Mime-Version: 1.0 (1.0)\r
Date: Tue, 13 Apr 2021 14:29:21 +0530\r
Subject: Inline image \r
Message-Id: <77881527-9B7E-4FF1-92A1-A731762A7AD8@xxx.com>\r
To: xxx@xxx.com\r
X-Mailer: iPhone Mail (18D70)\r
\r
\r
--Apple-Mail-96411171-B27C-4257-BB83-14E1DC508502\r
Content-Type: image/jpeg;\r
	name=image0.jpeg;\r
	x-apple-part-url=7CAB7826-682D-4FC4-9060-B59F36A45035-L0-001\r
Content-Disposition: inline;\r
	filename=image0.jpeg\r
Content-Transfer-Encoding: base64\r
\r
/9j/2wCEAAEBAQEBAQIBAQIDAgICAwQDAwMDBAUEBAQEBAUGBQUFBQUFBgYGBgYGBgYHBwcHBwcI\r
CAgICAkJCQkJCQkJCQkBAQEBAgICBAICBAkGBQYJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJCQkJ\r
CQkJCQkJCQkJCQkJCQkJCQkJCQkJCf/dAAQADf/AABEIACYAxgMBIgACEQEDEQH/xAGiAAABBQEB\r
AQEBAQAAAAAAAAAAAQIDBAUGBwgJCgsQAAIBAwMCBAMFBQQEAAABfQECAwAEEQUSITFBBhNRYQci\r
cRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5OkNERUZHSElKU1RVVldYWVpj\r
ZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfI\r
ycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+gEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcI\r
CQoLEQACAQIEBAMEBwUEBAABAncAAQIDEQQFITEGEkFRB2FxEyIygQgUQpGhscEJIzNS8BVictEK\r
FiQ04SXxFxgZGiYnKCkqNTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqCg4SF\r
hoeIiYqSk5SVlpeYmZqio6Slpqeoqaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2dri4+Tl5ufo\r
6ery8/T19vf4+fr/2gAMAwEAAhEDEQA/AP7+K/Gn/got/wAFy/2Ff+CbU58J/FbWJ/EHjBo/MHh7\r
QgtxeIOceexYRW+dvAkZa9V/4K4ftpXP/BPr9gDxv+0H4dUPrllbx6fo6n5v9OuyIYHAx8wiz5jL\r
3CGv4R/+Dcn4KfC/9vH/AIKC/EDXP2ytGj+Idy3hm71d21fdLvvWu7ZDM+7/AFhKSODu4z60Afr3\r
ff8AB598LUvjHYfBDUZoOiM2tQIT+HkkVUX/AIPPfh+4zH8Cb5gOuNbjOPyta+MfEn/BXb/g378O\r
+J7nw5f/ALHd601hdSW7GOPTwhkg/c8DzRnI6YFej/tJ/AT/AIJef8FE/wDgkH8Rf+Cgf7I/wjn+\r
D+r/AA6uZIraQKlsbp7fyllRhE8kMsBSXyxJjPnr7UAfR4/4PPPAZ6fAjUf/AAdR/wDyNVeT/g9E\r
+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\r
tRv9qjooKP/Z\r
--Apple-Mail-96411171-B27C-4257-BB83-14E1DC508502\r
Content-Type: text/plain;\r
	charset=us-ascii\r
Content-Transfer-Encoding: 7bit\r
\r
\r
\r
Sent from my iPhone\r
--Apple-Mail-96411171-B27C-4257-BB83-14E1DC508502--\r
''';
      final mime = MimeMessage.parseFromText(body);
      expect(mime.parts, isNotNull);
      expect(mime.parts!.length, 2);
      expect(mime.mediaType.sub, MediaSubtype.multipartMixed);
      final inlineInfos =
          mime.findContentInfo(disposition: ContentDisposition.inline);
      expect(inlineInfos.length, 1);
      final info = inlineInfos.first;
      expect(info.mediaType!.sub, MediaSubtype.imageJpeg);
      expect(info.fileName, 'image0.jpeg');
      expect(info.fetchId, '1');

      final part = mime.getPart(info.fetchId);
      expect(part, isNotNull);
      expect(part!.mediaType.sub, info.mediaType!.sub);
    });
  });

  group('RFC822 tests', () {
    test('UTF8 message', () {
      //origin:
      const body = '''Return-Path: <test-server@domain.mail>\r
Delivered-To: account@test.domain.mail\r
Date: Tue, 30 Mar 2021 09:54:40 +0200 (CEST)\r
From: "On behalf of: account@test.domain.mail" <test-server@domain.mail>\r
Reply-To: account@test.domain.mail\r
To: account@test.domain.mail\r
Message-ID: <94B20AE4-F0A8-0CB9-8FEE-9984E7D4759C@domain.mail>\r
Subject: =?ISO-8859-1?Q?CERTIFIED:_Test_emai?=\r
 =?ISO-8859-1?Q?l_with_unicode_characters_=E0=E8=F6?=\r
MIME-Version: 1.0\r
Content-Type: multipart/signed; protocol="application/pkcs7-signature"; micalg=sha-1; \r
	boundary="----=_Part_5490272_1539179725.1617090882104"\r
Importance: normal\r
\r
------=_Part_5490272_1539179725.1617090882104\r
Content-Type: multipart/mixed; \r
	boundary="----=_Part_5490270_1731033816.1617090882102"\r
\r
------=_Part_5490270_1731033816.1617090882102\r
Content-Type: text/plain; charset=ISO-8859-1\r
Content-Transfer-Encoding: quoted-printable\r
\r
Server wrapper message.\r
------=_Part_5490270_1731033816.1617090882102\r
Content-Type: message/rfc822; name=wrappedmsg.eml\r
Content-Disposition: attachment; filename=wrappedmsg.eml\r
\r
Message-ID: <94B20AE4-F0A8-0CB9-8FEE-9984E7D4759C@domain.mail>\r
MIME-Version: 1.0\r
X-VirusFound: false\r
X-Spam: Score=3.001\r
X-Virus-Scanned: amavisd-new at domain.mail\r
Date: Tue, 30 Mar 2021 09:54:40 +0200\r
From: account@test.domain.mail\r
To: account@test.domain.mail\r
Subject: =?UTF-8?Q?Test_email_with_unicode_characters_=C3=A0=C3=A8=C3=B6?=\r
X-Sender: account@test.domain.mail\r
User-Agent: Roundcube Webmail\r
Content-Type: multipart/alternative;\r
 boundary="=_3f11875cceb7d049b4b157dbf88b4e65"\r
X-TransactionId: 5e2dfdf6-6020-4670-a902-4366ac9b5f5a\r
\r
--=_3f11875cceb7d049b4b157dbf88b4e65\r
Content-Transfer-Encoding: 8bit\r
Content-Type: text/plain; charset=UTF-8\r
\r
This pårt of the emäįl contains various accéntè characterś\r 
\r
←←→→↑↓↑↓ⒶⒷ«SELECT»«START» \r
\r
List:\r 
\r
 	* one\r
 	* zwei\r
 	* tróis\r
 	* quátro\r
\r
-- long dash\r 
\r
enough_mail on GitHub [1] \r
\r
Links:\r
------\r
[1] https://github.com/enough_software/enough_mail\r
--=_3f11875cceb7d049b4b157dbf88b4e65\r
Content-Transfer-Encoding: quoted-printable\r
Content-Type: text/html; charset=UTF-8\r
\r
<html><head><meta http-equiv=3D"Content-Type" content=3D"text/html; charset=\r
=3DUTF-8" /></head><body style=3D'font-size: 10pt; font-family: Verdana,Gen=\r
eva,sans-serif'>\r
<p>This p&aring;rt of the em&auml;=C4=AFl contains various acc&eacute;nt&eg=\r
rave; character=C5=9B</p>\r
<p>&larr;&larr;&rarr;&rarr;&uarr;&darr;&uarr;&darr;=E2=92=B6=E2=92=B7&laquo=\r
;SELECT&raquo;&laquo;START&raquo;</p>\r
<p>List:</p>\r
<ol>\r
<li>one</li>\r
<li>zwei</li>\r
<li>tr&oacute;is</li>\r
<li>qu&aacute;tro</li>\r
</ol>\r
<p>&mdash; long dash</p>\r
<p><a title=3D"enough_mail" href=3D"https://github.com/enough_software/enou=\r
gh_mail" target=3D"_blank" rel=3D"noopener noreferrer">enough_mail on GitHu=\r
b</a></p>\r
\r
</body></html>\r
\r
--=_3f11875cceb7d049b4b157dbf88b4e65--\r
\r
------=_Part_5490270_1731033816.1617090882102\r
Content-Type: application/xml; name=data.xml\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment; filename=data.xml\r
\r
<redacted>\r
------=_Part_5490270_1731033816.1617090882102--\r
\r
------=_Part_5490272_1539179725.1617090882104\r
Content-Type: application/pkcs7-signature; name=smime.p7s; smime-type=signed-data\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment; filename="smime.p7s"\r
Content-Description: S/MIME Cryptographic Signature\r
\r
<redacted/>\r
------=_Part_5490272_1539179725.1617090882104--\r
''';

      final mime = MimeMessage.parseFromText(body);
      final messagePart = mime.getPart('1.2')!;
      expect(messagePart.mediaType.sub, MediaSubtype.messageRfc822);
      final embedded = messagePart.decodeContentMessage();
      expect(embedded, isNotNull);
      expect(
          embedded!.decodeSubject(),
          MailCodec.decodeHeader('=?UTF-8?Q?Test_email_with_unicode_characters'
              '_=C3=A0=C3=A8=C3=B6?='));
      expect(embedded.mediaType.sub, MediaSubtype.multipartAlternative);
      expect(
          embedded.decodeTextPlainPart()!.substring(
              0,
              'This pårt of the emäįl contains various accéntè characterś'
                  .length),
          'This pårt of the emäįl contains various accéntè characterś');
      // print(embedded.decodeTextHtmlPart());
      expect(
          embedded
              .decodeTextHtmlPart()!
              .contains('This p&aring;rt of the em&auml;įl contains various '
                  'acc&eacute;nt&egrave; characterś'),
          isTrue);
    });

    test('cp-1253 message', () {
      //origin:
      const body1 = '''Return-Path: <test-server@domain.mail>\r
Delivered-To: account@test.domain.mail\r
Date: Tue, 30 Mar 2021 09:54:40 +0200 (CEST)\r
From: "On behalf of: account@test.domain.mail" <test-server@domain.mail>\r
Reply-To: account@test.domain.mail\r
To: account@test.domain.mail\r
Message-ID: <94B20AE4-F0A8-0CB9-8FEE-9984E7D4759C@domain.mail>\r
Subject: =?ISO-8859-1?Q?CERTIFIED:_Test_emai?=\r
 =?ISO-8859-1?Q?l_with_unicode_characters_=E0=E8=F6?=\r
MIME-Version: 1.0\r
Content-Type: multipart/signed; protocol="application/pkcs7-signature"; micalg=sha-1; \r
	boundary="----=_Part_5490272_1539179725.1617090882104"\r
Importance: normal\r
\r
------=_Part_5490272_1539179725.1617090882104\r
Content-Type: multipart/mixed; \r
	boundary="----=_Part_5490270_1731033816.1617090882102"\r
\r
------=_Part_5490270_1731033816.1617090882102\r
Content-Type: text/plain; charset=ISO-8859-1\r
Content-Transfer-Encoding: quoted-printable\r
\r
Server wrapper message.\r
------=_Part_5490270_1731033816.1617090882102\r
Content-Type: message/rfc822; name=wrappedmsg.eml\r
Content-Disposition: attachment; filename=wrappedmsg.eml\r
\r
Message-ID: <94B20AE4-F0A8-0CB9-8FEE-9984E7D4759C@domain.mail>\r
MIME-Version: 1.0\r
X-VirusFound: false\r
X-Spam: Score=3.001\r
X-Virus-Scanned: amavisd-new at domain.mail\r
Date: Tue, 30 Mar 2021 09:54:40 +0200\r
From: account@test.domain.mail\r
To: account@test.domain.mail\r
Subject: =?UTF-8?Q?Test_email_with_unicode_characters_=C3=A0=C3=A8=C3=B6?=\r
X-Sender: account@test.domain.mail\r
User-Agent: Roundcube Webmail\r
Content-Type: multipart/alternative;\r
 boundary="=_3f11875cceb7d049b4b157dbf88b4e65"\r
X-TransactionId: 5e2dfdf6-6020-4670-a902-4366ac9b5f5a\r
\r
--=_3f11875cceb7d049b4b157dbf88b4e65\r
Content-Transfer-Encoding: 8bit\r
Content-Type: text/plain; charset="cp-1253"\r
\r
''';
      const body2 = '''\r
--=_3f11875cceb7d049b4b157dbf88b4e65\r
Content-Transfer-Encoding: 8bit\r
Content-Type: text/html; charset=cp-1253\r
\r
<html><body style='font-size: 10pt; font-family: Verdana,Geneva,sans-serif'>\r
<p>''';
      const body3 = '''</p>\r
</body></html>\r
\r
--=_3f11875cceb7d049b4b157dbf88b4e65--\r
\r
------=_Part_5490270_1731033816.1617090882102\r
Content-Type: application/xml; name=data.xml\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment; filename=data.xml\r
\r
<redacted/>\r
------=_Part_5490270_1731033816.1617090882102--\r
\r
------=_Part_5490272_1539179725.1617090882104\r
Content-Type: application/pkcs7-signature; name=smime.p7s; smime-type=signed-data\r
Content-Transfer-Encoding: base64\r
Content-Disposition: attachment; filename="smime.p7s"\r
Content-Description: S/MIME Cryptographic Signature\r
\r
<redacted/>\r
------=_Part_5490272_1539179725.1617090882104--\r
''';
      final bytes =
          const Windows1253Encoder().convert('Χαίρομαι που σας γνωρίζω!');
      final builder = BytesBuilder()
        ..add(utf8.encode(body1))
        ..add(bytes)
        ..add(utf8.encode(body2))
        ..add(bytes)
        ..add(utf8.encode(body3));
      final messageBytes = builder.toBytes();

      final mime = MimeMessage.parseFromData(messageBytes);
      final messagePart = mime.getPart('1.2');
      expect(messagePart?.mediaType.sub, MediaSubtype.messageRfc822);
      // print(messagePart.mimeData);
      // print('\n-------------------\n');
      // print(messagePart.decodeContentText());
      final embedded = messagePart?.decodeContentMessage();
      expect(embedded, isNotNull);
      expect(
        embedded?.decodeSubject(),
        MailCodec.decodeHeader('=?UTF-8?Q?Test_email_with_unicode_characters'
            '_=C3=A0=C3=A8=C3=B6?='),
      );
      expect(embedded?.mediaType.sub, MediaSubtype.multipartAlternative);
      // print(embedded.decodeTextPlainPart());
      expect(embedded?.decodeTextPlainPart(), 'Χαίρομαι που σας γνωρίζω!\r\n');
      // print(embedded.decodeTextHtmlPart());
      expect(
        embedded?.decodeTextHtmlPart()?.contains('Χαίρομαι που σας γνωρίζω!'),
        isTrue,
      );
    });
  });
}
