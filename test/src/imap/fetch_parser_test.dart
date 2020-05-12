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
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response);
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
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response);
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
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response);
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
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response);
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
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response);
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

  test('MODSEQ', () {
    var responseText = '* 50 FETCH (MODSEQ (12111230047))';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, true);
    var messages = parser.parse(details, response);
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].sequenceId, 50);
    expect(messages[0].modSequence, 12111230047);
  });

  test('HIGHESTMODSEQ', () {
    var responseText = '* OK [HIGHESTMODSEQ 12111230047]';
    var details = ImapResponse()..add(ImapResponseLine(responseText));
    var parser = FetchParser();
    var response = Response<List<MimeMessage>>()..status = ResponseStatus.OK;
    var processed = parser.parseUntagged(details, response);
    expect(processed, false);
  });
}
