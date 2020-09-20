import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/imap/all_parsers.dart';
import 'package:enough_mail/src/imap/imap_response_line.dart';
import 'package:enough_mail/src/imap/imap_response.dart';
import 'package:test/test.dart';

void main() {
  test('BODY 1', () {
    var responseText =
        '* 70 FETCH (UID 179 BODY (("text" "plain" ("charset" "utf8") NIL NIL "8bit" 45 3)("image" "jpg" ("charset" "utf8" "name" "testimage.jpg") NIL NIL "base64" 18324) "mixed"))';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].sequenceId, 70);
    var body = messages[0].body;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts.length, 2);
    expect(body.parts[0].contentType, isNotNull);
    expect(body.parts[0].contentType.mediaType, isNotNull);
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.text);
    expect(body.parts[0].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts[0].size, 45);
    expect(body.parts[0].numberOfLines, 3);
    expect(body.parts[0].contentType.charset, 'utf8');
    expect(body.parts[1].contentType.mediaType.top, MediaToptype.image);
    expect(body.parts[1].contentType.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.parts[1].contentType.parameters['name'], 'testimage.jpg');
    expect(body.parts[1].size, 18324);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
  });

  test('BODY 2', () {
    var responseText =
        '* 70 FETCH (BODY (("TEXT" "PLAIN" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 1152 '
        '23)("TEXT" "PLAIN" ("CHARSET" "US-ASCII" "NAME" "cc.diff")'
        '"<960723163407.20117h@cac.washington.edu>" "Compiler diff" '
        '"BASE64" 4554 73) "MIXED"))';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts.length, 2);
    expect(body.parts[0].contentType, isNotNull);
    expect(body.parts[0].contentType.mediaType, isNotNull);
    expect(body.parts[0].contentType.charset, 'us-ascii');
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.text);
    expect(body.parts[0].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts[0].size, 1152);
    expect(body.parts[0].numberOfLines, 23);
    expect(body.parts[0].encoding, '7bit');
    expect(body.parts[1].description, 'Compiler diff');
    expect(body.parts[1].id, '<960723163407.20117h@cac.washington.edu>');
    expect(body.parts[1].contentType.charset, 'us-ascii');
    expect(body.parts[1].contentType.parameters['name'], 'cc.diff');

    expect(body.parts[1].contentType.mediaType.top, MediaToptype.text);
    expect(body.parts[1].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts[1].size, 4554);
    expect(body.parts[1].numberOfLines, 73);
    expect(body.parts[1].encoding, 'base64');
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
  });

  test('BODY 3', () {
    var responseText =
        '* 32 FETCH (BODY (((("text" "plain" ("charset" "us-ascii") NIL NIL "7bit" 10252 819)'
        '("text" "html" ("charset" "us-ascii") NIL NIL "quoted-printable" 154063 2645) "alternative")'
        '("image" "png" ("name" "image001.png") "<image001.png@server>" NIL "base64" 29038)'
        '("image" "png" ("name" "image003.png") "<image003.png@server>" NIL "base64" 3286)'
        '("image" "png" ("name" "image005.png") "<image005.png@server>" NIL "base64" 3552)'
        '("image" "png" ("name" "image007.png") "<image007.png@server>" NIL "base64" 29874)'
        '("image" "png" ("name" "image008.png") "<image008.png@server>" NIL "base64" 3314)'
        '("image" "png" ("name" "image009.png") "<image009.png@server>" NIL "base64" 3576) "related")'
        '("application" "pdf" ("name" "name.pdf") NIL NIL "base64" 749602)'
        '("application" "pdf" ("name" "name.pdf") NIL NIL "base64" 611336)'
        '("application" "pdf" ("name" "name.pdf") NIL NIL "base64" 586426) "mixed"))';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.parts, isNotNull);
    expect(body.parts.length, 4);
    expect(body.parts[0].contentType, isNotNull);
    expect(body.parts[0].contentType.mediaType, isNotNull);
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.multipart);
    expect(
        body.parts[0].contentType.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.parts[0].parts, isNotEmpty);
    expect(body.parts[0].parts.length, 7);
    expect(body.parts[0].parts[0].contentType.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[0].parts[0].parts, isNotEmpty);
    expect(body.parts[0].parts[0].parts[0].contentType.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts[0].parts[0].parts[1].contentType.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts[0].parts[1].contentType.mediaType.sub,
        MediaSubtype.imagePng);
    expect(body.parts[0].parts[6].contentType.mediaType.sub,
        MediaSubtype.imagePng);
    expect(
        body.parts[1].contentType?.mediaType?.sub, MediaSubtype.applicationPdf);
    expect(
        body.parts[2].contentType?.mediaType?.sub, MediaSubtype.applicationPdf);
    expect(
        body.parts[3].contentType?.mediaType?.sub, MediaSubtype.applicationPdf);
  });

  test('BODYSTRUCTURE 1', () {
    var responseText = '* 70 FETCH (UID 179 BODYSTRUCTURE ('
        '("text" "plain" ("charset" "utf8") NIL NIL "8bit" 45 3 NIL NIL NIL NIL)'
        '("image" "jpg" ("charset" "utf8" "name" "testimage.jpg") NIL NIL "base64" 18324 NIL ("attachment" ("filename" "testimage.jpg" "modification-date" "Fri, 27 Jan 2017 16:34:4 +0100" "size" "13390")) NIL NIL) '
        '"mixed" ("charset" "utf8" "boundary" "cTOLC7EsqRfMsG") NIL NIL NIL))';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts.length, 2);
    expect(body.parts[0].contentType, isNotNull);
    expect(body.parts[0].contentType.mediaType, isNotNull);
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.text);
    expect(body.parts[0].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts[0].contentType.charset, 'utf8');
    expect(body.parts[0].contentDisposition, isNull);
    expect(body.parts[1].contentType.mediaType.top, MediaToptype.image);
    expect(body.parts[1].contentType.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.parts[1].contentType.parameters['name'], 'testimage.jpg');
    expect(body.parts[1].encoding, 'base64');
    var contentDisposition = body.parts[1].contentDisposition;
    expect(contentDisposition, isNotNull);
    expect(contentDisposition.dispositionText, 'attachment');
    expect(contentDisposition.disposition, ContentDisposition.attachment);
    expect(contentDisposition.size, 13390);
    expect(contentDisposition.modificationDate,
        DateCodec.decodeDate('Fri, 27 Jan 2017 16:34:4 +0100'));
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType.charset, 'utf8');
    expect(body.contentType.boundary, 'cTOLC7EsqRfMsG');
  });

  test('BODYSTRUCTURE 2', () {
    var responseTexts = [
      '* 2014 FETCH (FLAGS (\\Seen) BODYSTRUCTURE ('
          '('
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 2 1 NIL NIL NIL)'
          '("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "7BIT" 24 1 NIL NIL NIL) "ALTERNATIVE" '
          '("BOUNDARY" "00000000000005d37e05a528d9c3") NIL NIL'
          ')'
          '("APPLICATION" "PDF" ("NAME" "gdpr infomedica informativa clienti.pdf") "<171f5fa0424e36cb441>" NIL "BASE64" 238268 NIL '
          '("ATTACHMENT" ("FILENAME" "gdpr infomedica informativa clienti.pdf")) NIL) "MIXED" '
          '("BOUNDARY" "00000000000005d38005a528d9c5") NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType.boundary, '00000000000005d38005a528d9c5');
    expect(body.parts, isNotNull);
    expect(body.parts.length, 2);
    expect(body.parts[0].contentType, isNotNull);
    expect(body.parts[0].contentType.mediaType, isNotNull);
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.multipart);
    expect(body.parts[0].contentType.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[0].contentType.boundary, '00000000000005d37e05a528d9c3');
    expect(body.parts[0].parts, isNotNull);
    expect(body.parts[0].parts, isNotEmpty);
    expect(body.parts[0].parts.length, 2);
    expect(body.parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textPlain);
    expect(body.parts[0].parts[0].encoding, '7bit');
    expect(body.parts[0].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[0].parts[1].encoding, '7bit');
    expect(body.parts[1].contentType, isNotNull);
    expect(body.parts[1].contentType.mediaType, isNotNull);
    expect(
        body.parts[1].contentType.mediaType.sub, MediaSubtype.applicationPdf);
    expect(body.parts[1].contentType.parameters['name'],
        'gdpr infomedica informativa clienti.pdf');
    expect(body.parts[1].contentDisposition.disposition,
        ContentDisposition.attachment);
    expect(body.parts[1].contentDisposition.filename,
        'gdpr infomedica informativa clienti.pdf');
  });

  test('BODYSTRUCTURE 3', () {
    var responseTexts = [
      '* 2175 FETCH (UID 3641 FLAGS (\\Seen) BODYSTRUCTURE ('
          '('
          '('
          '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 274 6 NIL NIL NIL)'
          '("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 1455 30 NIL NIL NIL) '
          '"ALTERNATIVE" ("BOUNDARY" "0000000000002f322a05a71aaf69") NIL NIL'
          ')'
          '("IMAGE" "PNG" ("NAME" "icon.png") "<icon.png>" NIL "BASE64" 1986 NIL ("ATTACHMENT" ("FILENAME" "icon.png")) NIL) '
          '"RELATED" ("BOUNDARY" "0000000000002f322205a71aaf68") NIL NIL'
          ')'
          '("MESSAGE" "DELIVERY-STATUS" NIL NIL NIL "7BIT" 488 NIL NIL NIL)'
          '("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 2539 ("Tue, 2 Jun 2020 16:25:29 +0200" "tested" (("Tallah" NIL "Rocks" "domain.com")) (("Tallah" NIL "Rocks" "domain.com")) (("Tallah" NIL "Rocks" "domain.com")) (("Rocks@domain.com" NIL "Rocks" "domain.com")("Akari Haro" NIL "akari-haro" "domain.com")) NIL NIL NIL "GDQBjfh3TAG63B@domain.com") (("TEXT" "PLAIN" ("CHARSET" "utf8") NIL NIL "7BIT" 0 0 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "utf8") NIL NIL "8BIT" 1 1 NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "C6WuYgfyNiVn6u" "CHARSET" "utf8") NIL NIL) 51 NIL NIL NIL) "REPORT" ("BOUNDARY" "0000000000002f1f3705a71aaf47" "REPORT-TYPE" "delivery-status") NIL NIL'
          ')'
          ')'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].uid, 3641);
    expect(messages[0].flags, ['\\Seen']);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartReport);
    expect(body.contentType.boundary, '0000000000002f1f3705a71aaf47');
    expect(body.contentType.parameters['report-type'], 'delivery-status');
    expect(body.parts, isNotNull);
    expect(body.parts.length, 3);
    expect(body.parts[0].fetchId, '1');
    expect(body.parts[0].contentType, isNotNull);
    expect(body.parts[0].contentType.mediaType, isNotNull);
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.multipart);
    expect(
        body.parts[0].contentType.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.parts[0].contentType.boundary, '0000000000002f322205a71aaf68');
    expect(body.parts[0].parts, isNotNull);
    expect(body.parts[0].parts, isNotEmpty);
    expect(body.parts[0].parts.length, 2);
    expect(body.parts[0].parts[0].contentType?.mediaType?.top,
        MediaToptype.multipart);
    expect(body.parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[0].parts[0].contentType.boundary,
        '0000000000002f322a05a71aaf69');
    expect(body.parts[0].parts[0].parts.length, 2);
    expect(body.parts[0].parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textPlain);
    expect(body.parts[0].parts[0].parts[0].contentType?.charset, 'utf-8');
    expect(body.parts[0].parts[0].parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].parts[0].parts[0].size, 274);
    expect(body.parts[0].parts[0].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[0].parts[0].parts[1].contentType?.charset, 'utf-8');
    expect(body.parts[0].parts[0].parts[1].encoding, 'quoted-printable');
    expect(body.parts[0].parts[0].parts[1].size, 1455);
    expect(body.parts[1].contentType, isNotNull);
    expect(body.parts[1].contentType.mediaType, isNotNull);
    expect(body.parts[1].contentType.mediaType.top, MediaToptype.message);
    expect(body.parts[1].contentType.mediaType.sub,
        MediaSubtype.messageDeliveryStatus);
    expect(body.parts[1].size, 488);
    expect(body.parts[1].encoding, '7bit');
    expect(body.parts[2].contentType.mediaType.top, MediaToptype.message);
    expect(body.parts[2].contentType.mediaType.sub, MediaSubtype.messageRfc822);
    expect(body.parts[2].envelope, isNotNull);
    expect(body.parts[2].envelope.subject, 'tested');
    expect(body.parts[2].envelope.date,
        DateCodec.decodeDate('Tue, 2 Jun 2020 16:25:29 +0200'));
    expect(body.parts[2].envelope.from?.length, 1);
    expect(body.parts[2].envelope.from[0].email, 'Rocks@domain.com');
    expect(body.parts[2].envelope.to?.length, 2);
    expect(body.parts[2].envelope.to[0].email, 'Rocks@domain.com');
    expect(body.parts[2].envelope.to[1].email, 'akari-haro@domain.com');
    expect(body.parts[2].envelope.to[1].personalName, 'Akari Haro');
    expect(body.parts[2].parts?.length, 1);
    expect(body.parts[2].parts[0].contentType?.mediaType?.top,
        MediaToptype.multipart);
    expect(body.parts[2].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[2].parts[0].contentType?.boundary, 'C6WuYgfyNiVn6u');
    expect(body.parts[2].parts[0].contentType?.charset, 'utf8');
    expect(body.parts[2].parts[0].parts?.length, 2);
    expect(body.parts[2].parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textPlain);
    expect(body.parts[2].parts[0].parts[0].contentType?.charset, 'utf8');
    expect(body.parts[2].parts[0].parts[0].encoding, '7bit');
    expect(body.parts[2].parts[0].parts[0].size, 0);
    expect(body.parts[2].parts[0].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[2].parts[0].parts[1].contentType?.charset, 'utf8');
    expect(body.parts[2].parts[0].parts[1].encoding, '8bit');
    expect(body.parts[2].parts[0].parts[1].size, 1);
  });

  test('BODYSTRUCTURE 4 - single part', () {
    var responseTexts = [
      '* 2175 FETCH (BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 1315 42 NIL NIL NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.contentType.mediaType.top, MediaToptype.text);
    expect(body.contentType.charset, 'iso-8859-1');
    expect(body.encoding, 'quoted-printable');
    expect(body.size, 1315);
    expect(body.numberOfLines, 42);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 5 - simple alternative', () {
    var responseTexts = [
      '* 1 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 2234 63 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 2987 52 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "d3438gr7324") NIL NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartAlternative);
    expect(body.contentType.boundary, 'd3438gr7324');
    expect(body.parts?.length, 2);
    expect(body.parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].contentType?.mediaType?.sub, MediaSubtype.textPlain);
    expect(body.parts[0].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].size, 2234);
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[1].contentType?.mediaType?.sub, MediaSubtype.textHtml);
    expect(body.parts[1].contentType?.charset, 'iso-8859-1');
    expect(body.parts[1].encoding, 'quoted-printable');
    expect(body.parts[1].size, 2987);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 6 - simple alternative with image', () {
    var responseTexts = [
      '* 335 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 119 2 NIL ("INLINE" NIL) NIL)("IMAGE" "JPEG" ("NAME" "4356415.jpg") "<0__=rhksjt>" NIL "BASE64" 143804 NIL ("INLINE" ("FILENAME" "4356415.jpg")) NIL) "RELATED" ("BOUNDARY" "0__=5tgd3d") ("INLINE" NIL) NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.contentType.boundary, '0__=5tgd3d');
    //TODO
    //expect(body.contentDisposition?.disposition, ContentDisposition.inline);
    expect(body.parts?.length, 2);
    expect(body.parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].contentType?.mediaType?.sub, MediaSubtype.textHtml);
    expect(body.parts[0].contentType?.charset, 'us-ascii');
    expect(body.parts[0].encoding, '7bit');
    expect(body.parts[0].size, 119);
    expect(body.parts[0].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.image);
    expect(body.parts[1].contentType?.mediaType?.sub, MediaSubtype.imageJpeg);
    expect(body.parts[1].contentType?.parameters['name'], '4356415.jpg');
    expect(body.parts[1].encoding, 'base64');
    expect(body.parts[1].id, '<0__=rhksjt>');
    expect(body.parts[1].size, 143804);
    expect(body.parts[1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts[1].contentDisposition?.filename, '4356415.jpg');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 7 - text + html with images', () {
    var responseTexts = [
      '* 202 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1" "FORMAT" "flowed") NIL NIL "QUOTED-PRINTABLE" 2815 73 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4171 66 NIL NIL NIL NIL)("IMAGE" "JPEG" ("NAME" "image.jpg") "<3245dsf7435>" NIL "BASE64" 189906 NIL NIL NIL NIL)("IMAGE" "GIF" ("NAME" "other.gif") "<32f6324f>" NIL "BASE64" 1090 NIL NIL NIL NIL) "RELATED" ("BOUNDARY" "--=sdgqgt") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "--=u5sfrj") NIL NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartAlternative);
    expect(body.contentType.boundary, '--=u5sfrj');
    expect(body.parts?.length, 2);
    expect(body.parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].contentType?.mediaType?.sub, MediaSubtype.textPlain);
    expect(body.parts[0].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].contentType?.isFlowedFormat, true);
    expect(body.parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].size, 2815);
    // expect(body.parts[0].contentDisposition?.disposition,
    //     ContentDisposition.inline);
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.multipart);
    expect(body.parts[1].contentType?.mediaType?.sub,
        MediaSubtype.multipartRelated);
    expect(body.parts[1].contentType?.boundary, '--=sdgqgt');
    expect(body.parts[1].parts?.length, 3);
    expect(
        body.parts[1].parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[1].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[1].parts[0].contentType?.charset, 'iso-8859-1');
    expect(body.parts[1].parts[0].encoding, 'quoted-printable');
    expect(
        body.parts[1].parts[1].contentType?.mediaType?.top, MediaToptype.image);
    expect(body.parts[1].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.imageJpeg);
    expect(body.parts[1].parts[1].contentType?.parameters['name'], 'image.jpg');
    expect(body.parts[1].parts[1].id, '<3245dsf7435>');
    expect(body.parts[1].parts[1].encoding, 'base64');
    expect(body.parts[1].parts[1].size, 189906);
    expect(
        body.parts[1].parts[2].contentType?.mediaType?.top, MediaToptype.image);
    expect(body.parts[1].parts[2].contentType?.mediaType?.sub,
        MediaSubtype.imageGif);
    expect(body.parts[1].parts[2].contentType?.parameters['name'], 'other.gif');
    expect(body.parts[1].parts[2].id, '<32f6324f>');
    expect(body.parts[1].parts[2].encoding, 'base64');
    expect(body.parts[1].parts[2].size, 1090);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 8 - text + html with images 2', () {
    var responseTexts = [
      '* 41 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 471 28 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 1417 36 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "1__=hqjksdm") NIL NIL)("IMAGE" "GIF" ("NAME" "image.gif") "<1__=cxdf2f>" NIL "BASE64" 50294 NIL ("INLINE" ("FILENAME" "image.gif")) NIL) "RELATED" ("BOUNDARY" "0__=hqjksdm") NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.contentType.boundary, '0__=hqjksdm');
    expect(body.parts?.length, 2);
    expect(body.parts[0].contentType?.mediaType?.top, MediaToptype.multipart);
    expect(body.parts[0].contentType?.mediaType?.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[0].contentType?.boundary, '1__=hqjksdm');
    expect(body.parts[0].parts?.length, 2);
    expect(
        body.parts[0].parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textPlain);
    expect(body.parts[0].parts[0].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].parts[0].size, 471);
    expect(
        body.parts[0].parts[1].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[0].parts[1].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].parts[1].encoding, 'quoted-printable');
    expect(body.parts[0].parts[1].size, 1417);
    expect(body.parts[0].parts[1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.image);
    expect(body.parts[1].contentType?.mediaType?.sub, MediaSubtype.imageGif);
    expect(body.parts[1].contentType?.parameters['name'], 'image.gif');
    expect(body.parts[1].id, '<1__=cxdf2f>');
    expect(body.parts[1].encoding, 'base64');
    expect(body.parts[1].size, 50294);
    expect(body.parts[1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts[1].contentDisposition?.filename, 'image.gif');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 9 - mail with attachment', () {
    var responseTexts = [
      '* 302 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4692 69 NIL NIL NIL NIL)("APPLICATION" "PDF" ("NAME" "pages.pdf") NIL NIL "BASE64" 38838 NIL ("attachment" ("FILENAME" "pages.pdf")) NIL NIL) "MIXED" ("BOUNDARY" "----=6fgshr") NIL NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType.boundary, '----=6fgshr');
    expect(body.parts?.length, 2);
    expect(body.parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].contentType?.mediaType?.sub, MediaSubtype.textHtml);
    expect(body.parts[0].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].size, 4692);
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.application);
    expect(
        body.parts[1].contentType?.mediaType?.sub, MediaSubtype.applicationPdf);
    expect(body.parts[1].contentType?.parameters['name'], 'pages.pdf');
    expect(body.parts[1].encoding, 'base64');
    expect(body.parts[1].size, 38838);
    expect(body.parts[1].contentDisposition?.disposition,
        ContentDisposition.attachment);
    expect(body.parts[1].contentDisposition?.filename, 'pages.pdf');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 10 - alternative and attachment', () {
    var responseTexts = [
      '* 356 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 403 6 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 421 6 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "----=fghgf3") NIL NIL NIL)("APPLICATION" "vnd.openxmlformats-officedocument.wordprocessingml.document" ("NAME" "letter.docx") NIL NIL "BASE64" 110000 NIL ("attachment" ("FILENAME" "letter.docx" "SIZE" "80384")) NIL NIL) "MIXED" ("BOUNDARY" "----=y34fgl") NIL NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType.boundary, '----=y34fgl');
    expect(body.parts?.length, 2);
    expect(body.parts[0].fetchId, '1');
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.multipart);
    expect(body.parts[0].contentType.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[0].contentType.boundary, '----=fghgf3');
    expect(body.parts[0].parts?.length, 2);
    expect(body.parts[0].parts[0].fetchId, '1.1');
    expect(
        body.parts[0].parts[0].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textPlain);
    expect(body.parts[0].parts[0].contentType?.charset, 'utf-8');
    expect(body.parts[0].parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].parts[0].size, 403);
    expect(body.parts[0].parts[1].fetchId, '1.2');
    expect(
        body.parts[0].parts[1].contentType?.mediaType?.top, MediaToptype.text);
    expect(body.parts[0].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[0].parts[1].contentType?.charset, 'utf-8');
    expect(body.parts[0].parts[1].encoding, 'quoted-printable');
    expect(body.parts[0].parts[1].size, 421);
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.application);
    expect(body.parts[1].fetchId, '2');
    expect(body.parts[1].contentType?.mediaType?.sub,
        MediaSubtype.applicationOfficeDocumentWordProcessingDocument);
    expect(body.parts[1].contentType?.parameters['name'], 'letter.docx');
    expect(body.parts[1].encoding, 'base64');
    expect(body.parts[1].size, 110000);
    expect(body.parts[1].contentDisposition?.disposition,
        ContentDisposition.attachment);
    expect(body.parts[1].contentDisposition?.filename, 'letter.docx');
    expect(body.parts[1].contentDisposition?.size, 80384);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 11 - all together', () {
    var responseTexts = [
      '* 1569 FETCH (BODYSTRUCTURE (((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 833 30 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 3412 62 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "2__=fgrths") NIL NIL)("IMAGE" "GIF" ("NAME" "485039.gif") "<2__=lgkfjr>" NIL "BASE64" 64 NIL ("INLINE" ("FILENAME" "485039.gif")) NIL) "RELATED" ("BOUNDARY" "1__=fgrths") NIL NIL)("APPLICATION" "PDF" ("NAME" "title.pdf") "<1__=lgkfjr>" NIL "BASE64" 333980 NIL ("ATTACHMENT" ("FILENAME" "title.pdf")) NIL) "MIXED" ("BOUNDARY" "0__=fgrths") NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType.boundary, '0__=fgrths');
    expect(body.parts?.length, 2);
    expect(body.parts[0].fetchId, '1');
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.multipart);
    expect(
        body.parts[0].contentType.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.parts[0].contentType.boundary, '1__=fgrths');
    expect(body.parts[0].parts?.length, 2);
    expect(body.parts[0].parts[0].contentType.mediaType.top,
        MediaToptype.multipart);
    expect(body.parts[0].parts[0].contentType.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts[0].parts[0].contentType.boundary, '2__=fgrths');
    expect(body.parts[0].parts[0].fetchId, '1.1');
    expect(body.parts[0].parts[0].parts?.length, 2);
    expect(body.parts[0].parts[0].parts[0].fetchId, '1.1.1');
    expect(body.parts[0].parts[0].parts[0].contentType?.mediaType?.top,
        MediaToptype.text);
    expect(body.parts[0].parts[0].parts[0].contentType?.mediaType?.sub,
        MediaSubtype.textPlain);
    expect(body.parts[0].parts[0].parts[0].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].parts[0].parts[0].encoding, 'quoted-printable');
    expect(body.parts[0].parts[0].parts[0].size, 833);
    expect(body.parts[0].parts[0].parts[1].fetchId, '1.1.2');
    expect(body.parts[0].parts[0].parts[1].contentType?.mediaType?.top,
        MediaToptype.text);
    expect(body.parts[0].parts[0].parts[1].contentType?.mediaType?.sub,
        MediaSubtype.textHtml);
    expect(body.parts[0].parts[0].parts[1].contentType?.charset, 'iso-8859-1');
    expect(body.parts[0].parts[0].parts[1].encoding, 'quoted-printable');
    expect(body.parts[0].parts[0].parts[1].size, 3412);
    expect(body.parts[0].parts[0].parts[1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts[1].fetchId, '2');
    expect(body.parts[1].contentType?.mediaType?.top, MediaToptype.application);
    expect(
        body.parts[1].contentType?.mediaType?.sub, MediaSubtype.applicationPdf);
    expect(body.parts[1].contentType?.parameters['name'], 'title.pdf');
    expect(body.parts[1].encoding, 'base64');
    expect(body.parts[1].id, '<1__=lgkfjr>');
    expect(body.parts[1].size, 333980);
    expect(body.parts[1].contentDisposition?.disposition,
        ContentDisposition.attachment);
    expect(body.parts[1].contentDisposition?.filename, 'title.pdf');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 12 - single-element lists', () {
    var responseTexts = [
      '* 2246 FETCH (BODYSTRUCTURE (("TEXT" "HTML" NIL NIL NIL "7BIT" 151 0 NIL NIL NIL) "MIXED" ("BOUNDARY" "----=rfsewr") NIL NIL))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    var body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType.mediaType, isNotNull);
    expect(body.contentType.mediaType.top, MediaToptype.multipart);
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType.boundary, '----=rfsewr');
    expect(body.parts?.length, 1);
    expect(body.parts[0].contentType.mediaType.top, MediaToptype.text);
    expect(body.parts[0].contentType.mediaType.sub, MediaSubtype.textHtml);
    expect(body.parts[0].encoding, '7bit');
    expect(body.parts[0].size, 151);
    expect(body.parts[0].fetchId, '1');
  });

  test('MODSEQ', () {
    var responseText = '* 50 FETCH (MODSEQ (12111230047))';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].sequenceId, 50);
    expect(messages[0].modSequence, 12111230047);
  });

  test('HIGHESTMODSEQ', () {
    var responseText = '* OK [HIGHESTMODSEQ 12111230047]';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, false);
  });

  test('VANISHED', () {
    var responseText = '* VANISHED (EARLIER) 300:310,405,411';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);

    expect(processed, true);
    expect(parser.lastParsedMessage, isNull);
    expect(parser.vanishedMessages, isNotNull);
    expect(parser.vanishedMessages.toList(),
        [300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 405, 411]);
    var result = parser.parse(details, response);
    expect(result.messages, isEmpty);
    expect(result.vanishedMessagesUidSequence, isNotNull);
    expect(result.vanishedMessagesUidSequence.toList(),
        [300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 405, 411]);
  });

  test('BODY[2.1]', () {
    var responseText1 = '* 50 FETCH (BODY[2.1] {359}';
    var responseText2 = 'Date: Wed, 17 Jul 1996 02:23:25 -0700 (PDT)\r\n'
        'From: Terry Gray <gray@cac.washington.edu>\r\n'
        'Subject: IMAP4rev1 WG mtg summary and minutes\r\n'
        'To: imap@cac.washington.edu\r\n'
        'cc: minutes@CNRI.Reston.VA.US, \r\n'
        '   John Klensin <KLENSIN@MIT.EDU>\r\n'
        'Message-Id: <B27397-0100000@cac.washington.edu>\r\n'
        'MIME-Version: 1.0\r\n'
        'Content-Type: TEXT/PLAIN; CHARSET=US-ASCII\r\n'
        '\r\n'
        'Hello Word\r\n';
    var responseText3 = ')';

    var details = ImapResponse()
      ..add(ImapResponseLine(responseText1))
      ..add(ImapResponseLine(responseText2))
      ..add(ImapResponseLine(responseText3));
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var result = parser.parse(details, response);
    expect(result.messages, isNotEmpty);
    expect(result.messages.length, 1);
    var part = result.messages[0].getPart('2.1');
    expect(part, isNotNull);
    expect(part.getHeaderContentType(), isNotNull);
    expect(part.getHeaderContentType().mediaType?.sub, MediaSubtype.textPlain);
    expect(part.getHeaderValue('message-id'),
        '<B27397-0100000@cac.washington.edu>');
  });

  test('ENVELOPE 1', () {
    var responseTexts = [
      r'* 61792 FETCH (UID 347524 RFC822.SIZE 4579 ENVELOPE ("Sun, 9 Aug 2020 09:03:12 +0200 (CEST)" "Re: Your Query" (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) ((NIL NIL "recipient" "enough.de")) NIL NIL NIL "<9jbzp5olgc9n54qwutoty0pnxunmoyho5ugshxplpvudvurjwh3a921kjdwkpwrf9oe06g95k69t@mail.ebay-kleinanzeigen.de>") FLAGS (\Seen))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].uid, 347524);
    expect(messages[0].size, 4579);
    expect(messages[0].flags, ['\\Seen']);
    expect(messages[0].from, isNotNull);
    expect(messages[0].from.length, 1);
    expect(messages[0].from[0].email,
        'anbieter-sdkjskjfkd@mail.ebay-kleinanzeigen.de');
    expect(
        messages[0].from[0].personalName, 'C. Sender über eBay Kleinanzeigen');
    expect(messages[0].decodeSubject(), 'Re: Your Query');
  });

  test('ENVELOPE 2 with escaped quote in subject', () {
    var responseTexts = [
      r'* 61792 FETCH (UID 347524 RFC822.SIZE 4579 ENVELOPE ("Sun, 9 Aug 2020 09:03:12 +0200 (CEST)" "Re: Your Query about \"Table\"" (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) ((NIL NIL "recipient" "enough.de")) NIL NIL NIL "<9jbzp5olgc9n54qwutoty0pnxunmoyho5ugshxplpvudvurjwh3a921kjdwkpwrf9oe06g95k69t@mail.ebay-kleinanzeigen.de>") FLAGS (\Seen))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response).messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].uid, 347524);
    expect(messages[0].size, 4579);
    expect(messages[0].flags, ['\\Seen']);
    expect(messages[0].decodeSubject(), 'Re: Your Query about "Table"');
    expect(messages[0].from, isNotNull);
    expect(messages[0].from.length, 1);
    expect(messages[0].from[0].email,
        'anbieter-sdkjskjfkd@mail.ebay-kleinanzeigen.de');
    expect(
        messages[0].from[0].personalName, 'C. Sender über eBay Kleinanzeigen');
  });

  test('measure performance', () {
    var responseTexts = [
      r'* 61792 FETCH (UID 347524 RFC822.SIZE 4579 ENVELOPE ("Sun, 9 Aug 2020 09:03:12 +0200 (CEST)" "Re: Your Query about \"Table\"" (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) ((NIL NIL "recipient" "enough.de")) NIL NIL NIL "<9jbzp5olgc9n54qwutoty0pnxunmoyho5ugshxplpvudvurjwh3a921kjdwkpwrf9oe06g95k69t@mail.ebay-kleinanzeigen.de>") FLAGS (\Seen))'
    ];
    var details = ImapResponse();
    for (var text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    var parser = FetchParser();
    var response = Response<FetchImapResult>()..status = ResponseStatus.OK;
    final stopwatch = Stopwatch()..start();
    for (var i = 10000; --i >= 0;) {
      var processed = parser.parseUntagged(details, response);
      if (!processed) {
        fail('unable to parse during performance test at round $i');
      }
    }
    //print('elapsed time: ${stopwatch.elapsedMicroseconds}');
    stopwatch.stop();
  });
}
