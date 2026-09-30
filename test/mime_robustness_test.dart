import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:test/test.dart';

void main() {
  group('quoted-printable', () {
    test('malformed sequences never throw', () {
      const qp = MailCodec.quotedPrintable;
      expect(qp.decodeText('Hello=', utf8), 'Hello=');
      expect(qp.decodeText('Hello=A', utf8), 'Hello=A');
      expect(qp.decodeText('=C3=A', utf8), 'Ã=A');
      expect(qp.decodeText('=C3=ZZ', utf8), 'Ã=ZZ');
      expect(qp.decodeText('x=-1y', utf8), 'x=-1y');
      expect(qp.decodeText('=C3=A4', utf8), 'ä');
      expect(qp.decodeText('a=\r\nb=\nc', utf8), 'abc');
    });

    test('malformed encoded words in headers are kept as is', () {
      expect(MailCodec.decodeHeader('=?utf-8?Q?abc=?='), 'abc=');
      expect(MailCodec.decodeHeader('=?utf-8?B?!!!!?='), '');
      expect(MailCodec.decodeHeader('=?utf-8?Q?=C3=A4?='), 'ä');
    });
  });

  group('base64', () {
    test('ignores invalid characters and fixes padding', () {
      const b64 = MailCodec.base64;
      expect(b64.decodeText('aGVs bG8=', utf8), 'hello');
      expect(b64.decodeText('aGVs\nbG8', utf8), 'hello');
      expect(b64.decodeText('aGVsbG8=trailing', utf8), 'hello');
      expect(b64.decodeText('!!!!', utf8), '');
      expect(b64.decodeText('A', utf8), '');
    });

    test('bare LF base64 attachments decode from binary data', () {
      const text =
          'Content-Type: application/octet-stream\r\n'
          'Content-Transfer-Encoding: base64\r\n\r\n'
          'aGVs\nbG8=\r\n';
      final message = MimeMessage.parseFromData(utf8.encode(text));
      expect(utf8.decode(message.decodeContentBinary()!), 'hello');
    });
  });

  group('binary transfer encodings', () {
    test('binary and 8bit bodies are returned byte for byte', () {
      final header = utf8.encode(
        'Content-Type: application/octet-stream\r\n'
        'Content-Transfer-Encoding: binary\r\n\r\n',
      );
      final body = [0xFF, 0xC3, 0xA9, 0x00, 0x0D, 0x0A];
      final message = MimeMessage.parseFromData(
        Uint8List.fromList([...header, ...body]),
      );
      expect(message.decodeContentBinary(), body);
    });

    test('quoted-printable attachments are decoded from binary data', () {
      const text =
          'Content-Type: application/pdf\r\n'
          'Content-Transfer-Encoding: quoted-printable\r\n\r\n'
          '=25PDF=2D1=2E7\r\n';
      final message = MimeMessage.parseFromData(utf8.encode(text));
      expect(
        String.fromCharCodes(message.decodeContentBinary()!),
        startsWith('%PDF-1.7'),
      );
    });
  });

  group('parts', () {
    test('getPartWithContentId accepts any cid notation', () {
      const text =
          'Content-Type: multipart/related; boundary="b"\r\n\r\n'
          '--b\r\nContent-Type: text/html\r\n\r\n<img src="cid:Image1@foo">\r\n'
          '--b\r\nContent-Type: image/png\r\nContent-ID: <Image1@foo>\r\n\r\nx\r\n'
          '--b--\r\n';
      final message = MimeMessage.parseFromText(text);
      expect(message.getPartWithContentId('Image1@foo'), isNotNull);
      expect(message.getPartWithContentId('<Image1@foo>'), isNotNull);
      expect(message.getPartWithContentId('<image1@foo>'), isNotNull);
    });

    test('text lookup ignores attached messages and text attachments', () {
      const text =
          'Content-Type: multipart/mixed; boundary="b"\r\n\r\n'
          '--b\r\nContent-Type: text/html\r\n\r\n<p>outer</p>\r\n'
          '--b\r\nContent-Type: message/rfc822\r\n\r\n'
          'Content-Type: text/plain\r\n\r\nforwarded text\r\n'
          '--b\r\nContent-Type: text/plain\r\n'
          'Content-Disposition: attachment; filename="notes.txt"\r\n\r\n'
          'attached notes\r\n'
          '--b--\r\n';
      final message = MimeMessage.parseFromText(text);
      expect(message.decodeTextHtmlPart(), '<p>outer</p>\r\n');
      expect(message.decodeTextPlainPart(), isNull);
    });
  });

  group('header parameters', () {
    test('are split at unquoted semicolons only and trimmed', () {
      final header = ContentDispositionHeader(
        'attachment; filename="a;b.txt" ; size=3',
      );
      expect(header.filename, 'a;b.txt');
      expect(header.size, 3);
      final contentType = ContentTypeHeader('text/plain ; charset=utf-8');
      expect(contentType.mediaType.sub, MediaSubtype.textPlain);
      expect(contentType.charset, 'utf-8');
    });

    test('decodes RFC 2231 encoded and continued parameters', () {
      final header = ContentDispositionHeader(
        "attachment; filename*=UTF-8''%E2%82%AC%20rates.txt",
      );
      expect(header.filename, '€ rates.txt');
      final continued = ContentDispositionHeader(
        "attachment; filename*0*=iso-8859-1''Gr%FC%DFe%20; "
        'filename*1*=aus%20; filename*2="München.txt"',
      );
      expect(continued.filename, 'Grüße aus München.txt');
    });

    test('a message/rfc822 part with astral display names parses', () {
      const text =
          'From: "😀 Bob" <bob@example.com>\r\nSubject: hi\r\n\r\nbody';
      final message = MimeMessage.parseFromText(text);
      expect(message.from?.first.email, 'bob@example.com');
      expect(message.from?.first.personalName, '😀 Bob');
    });
  });
}
