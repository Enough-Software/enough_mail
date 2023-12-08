import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/imap/all_parsers.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:test/test.dart';
// cSpell:disable

void main() {
  test('BODY 1', () {
    const responseText =
        '''* 70 FETCH (UID 179 BODY (("text" "plain" ("charset" "utf8") NIL NIL "8bit" 45 3)("image" "jpg" ("charset" "utf8" "name" "testimage.jpg") NIL NIL "base64" 18324) "mixed"))''';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].sequenceId, 70);
    final body = messages[0].body!;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 2);
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![0].size, 45);
    expect(body.parts![0].numberOfLines, 3);
    expect(body.parts![0].contentType!.charset, 'utf8');
    expect(body.parts![1].contentType!.mediaType.top, MediaToptype.image);
    expect(body.parts![1].contentType!.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.parts![1].contentType!.parameters['name'], 'testimage.jpg');
    expect(body.parts![1].size, 18324);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
  });

  test('BODY 2', () {
    const responseText =
        '* 70 FETCH (BODY (("TEXT" "PLAIN" ("CHARSET" "US-ASCII") NIL NIL '
        '"7BIT" 1152 '
        '23)("TEXT" "PLAIN" ("CHARSET" "US-ASCII" "NAME" "cc.diff")'
        '"<960723163407.20117h@cac.washington.edu>" "Compiler diff" '
        '"BASE64" 4554 73) "MIXED"))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 2);
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.charset, 'us-ascii');
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![0].size, 1152);
    expect(body.parts![0].numberOfLines, 23);
    expect(body.parts![0].encoding, '7bit');
    expect(body.parts![1].description, 'Compiler diff');
    expect(body.parts![1].cid, '<960723163407.20117h@cac.washington.edu>');
    expect(body.parts![1].contentType!.charset, 'us-ascii');
    expect(body.parts![1].contentType!.parameters['name'], 'cc.diff');

    expect(body.parts![1].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![1].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![1].size, 4554);
    expect(body.parts![1].numberOfLines, 73);
    expect(body.parts![1].encoding, 'base64');
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
  });

  test('BODY 3', () {
    const responseText =
        '* 32 FETCH (BODY (((("text" "plain" ("charset" "us-ascii") NIL NIL '
        '"7bit" 10252 819)'
        '("text" "html" ("charset" "us-ascii") NIL NIL "quoted-printable" '
        '154063 2645) "alternative")'
        '("image" "png" ("name" "image001.png") "<image001.png@server>" NIL '
        '"base64" 29038)'
        '("image" "png" ("name" "image003.png") "<image003.png@server>" NIL '
        '"base64" 3286)'
        '("image" "png" ("name" "image005.png") "<image005.png@server>" NIL '
        '"base64" 3552)'
        '("image" "png" ("name" "image007.png") "<image007.png@server>" NIL '
        '"base64" 29874)'
        '("image" "png" ("name" "image008.png") "<image008.png@server>" NIL '
        '"base64" 3314)'
        '("image" "png" ("name" "image009.png") "<image009.png@server>" NIL '
        '"base64" 3576) "related")'
        '("application" "pdf" ("name" "name.pdf") NIL NIL "base64" 749602)'
        '("application" "pdf" ("name" "name.pdf") NIL NIL "base64" 611336)'
        '("application" "pdf" ("name" "name.pdf") NIL NIL "base64" 586426) '
        '"mixed"))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 4);
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartRelated);
    expect(body.parts![0].parts, isNotEmpty);
    expect(body.parts![0].parts!.length, 7);
    expect(body.parts![0].parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![0].parts![0].parts, isNotEmpty);
    expect(body.parts![0].parts![0].parts![0].contentType!.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![0].parts![0].parts![1].contentType!.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![0].parts![1].contentType!.mediaType.sub,
        MediaSubtype.imagePng);
    expect(body.parts![0].parts![6].contentType!.mediaType.sub,
        MediaSubtype.imagePng);
    expect(
        body.parts![1].contentType?.mediaType.sub, MediaSubtype.applicationPdf);
    expect(
        body.parts![2].contentType?.mediaType.sub, MediaSubtype.applicationPdf);
    expect(
        body.parts![3].contentType?.mediaType.sub, MediaSubtype.applicationPdf);
  });

  test('BODY 4 with encoded filename', () {
    const responseText =
        '''* 70 FETCH (UID 179 BODY (("text" "plain" ("charset" "utf8") NIL NIL "8bit" 45 3)("audio" "mp4" ("charset" "utf8" "name" "=?iso-8859-1?Q?01_So_beeinflu=DFbar.m4a?=") NIL "=?iso-8859-1?Q?01_So_beeinflu=DFbar.m4a?=" "base64" 18324) "mixed"))''';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].sequenceId, 70);
    final body = messages[0].body!;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 2);
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![0].size, 45);
    expect(body.parts![0].numberOfLines, 3);
    expect(body.parts![0].contentType!.charset, 'utf8');
    expect(body.parts![1].contentType!.mediaType.top, MediaToptype.audio);
    expect(body.parts![1].contentType!.mediaType.sub, MediaSubtype.audioMp4);
    expect(body.parts![1].contentType!.parameters['name'],
        '=?iso-8859-1?Q?01_So_beeinflu=DFbar.m4a?=');
    expect(body.parts![1].description,
        '=?iso-8859-1?Q?01_So_beeinflu=DFbar.m4a?=');
    expect(body.parts![1].size, 18324);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
  });

  test('BODYSTRUCTURE 1', () {
    const responseText = '* 70 FETCH (UID 179 BODYSTRUCTURE ('
        '("text" "plain" ("charset" "utf8") NIL NIL "8bit" 45 3 NIL NIL NIL '
        'NIL)'
        '("image" "jpg" ("charset" "utf8" "name" "testimage.jpg") NIL NIL '
        '"base64" 18324 NIL ("attachment" ("filename" "testimage.jpg" "modifica'
        'tion-date" "Fri, 27 Jan 2017 16:34:4 +0100" "size" "13390")) NIL NIL) '
        '"mixed" ("charset" "utf8" "boundary" "cTOLC7EsqRfMsG") NIL NIL NIL))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    expect(body, isNotNull);
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 2);
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![0].contentType!.charset, 'utf8');
    expect(body.parts![0].contentDisposition, isNull);
    expect(body.parts![1].contentType!.mediaType.top, MediaToptype.image);
    expect(body.parts![1].contentType!.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.parts![1].contentType!.parameters['name'], 'testimage.jpg');
    expect(body.parts![1].encoding, 'base64');
    final contentDisposition = body.parts![1].contentDisposition!;
    expect(contentDisposition, isNotNull);
    expect(contentDisposition.dispositionText, 'attachment');
    expect(contentDisposition.disposition, ContentDisposition.attachment);
    expect(contentDisposition.size, 13390);
    expect(contentDisposition.modificationDate,
        DateCodec.decodeDate('Fri, 27 Jan 2017 16:34:4 +0100'));
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.charset, 'utf8');
    expect(body.contentType!.boundary, 'cTOLC7EsqRfMsG');
  });

  test('BODYSTRUCTURE 2', () {
    const responseText = '* 2014 FETCH (FLAGS (\\Seen) BODYSTRUCTURE ('
        '('
        '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "7BIT" 2 1 NIL NIL NIL)'
        '("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "7BIT" 24 1 NIL NIL NIL) '
        '"ALTERNATIVE" '
        '("BOUNDARY" "00000000000005d37e05a528d9c3") NIL NIL'
        ')'
        '("APPLICATION" "PDF" ("NAME" "gdpr infomedica informativa clienti.p'
        'df") "<171f5fa0424e36cb441>" NIL "BASE64" 238268 NIL '
        '("ATTACHMENT" ("FILENAME" "gdpr infomedica informativa clienti.pdf")'
        ') NIL) "MIXED" '
        '("BOUNDARY" "00000000000005d38005a528d9c5") NIL NIL))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '00000000000005d38005a528d9c5');
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 2);
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(
        body.parts![0].contentType!.boundary, '00000000000005d37e05a528d9c3');
    expect(body.parts![0].parts, isNotNull);
    expect(body.parts![0].parts, isNotEmpty);
    expect(body.parts![0].parts!.length, 2);
    expect(body.parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![0].parts![0].encoding, '7bit');
    expect(body.parts![0].parts![1].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![0].parts![1].encoding, '7bit');
    expect(body.parts![1].contentType, isNotNull);
    expect(body.parts![1].contentType!.mediaType, isNotNull);
    expect(
        body.parts![1].contentType!.mediaType.sub, MediaSubtype.applicationPdf);
    expect(body.parts![1].contentType!.parameters['name'],
        'gdpr infomedica informativa clienti.pdf');
    expect(body.parts![1].contentDisposition!.disposition,
        ContentDisposition.attachment);
    expect(body.parts![1].contentDisposition!.filename,
        'gdpr infomedica informativa clienti.pdf');
  });

  test('BODYSTRUCTURE 3', () {
    const responseText = '* 2175 FETCH (UID 3641 FLAGS (\\Seen) BODYSTRUCTURE ('
        '('
        '('
        '("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 274 '
        '6 NIL NIL NIL)'
        '("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 1455 '
        '30 NIL NIL NIL) '
        '"ALTERNATIVE" ("BOUNDARY" "0000000000002f322a05a71aaf69") NIL NIL'
        ')'
        '("IMAGE" "PNG" ("NAME" "icon.png") "<icon.png>" NIL "BASE64" 1986 '
        'NIL ("ATTACHMENT" ("FILENAME" "icon.png")) NIL) '
        '"RELATED" ("BOUNDARY" "0000000000002f322205a71aaf68") NIL NIL'
        ')'
        '("MESSAGE" "DELIVERY-STATUS" NIL NIL NIL "7BIT" 488 NIL NIL NIL)'
        '("MESSAGE" "RFC822" NIL NIL NIL "7BIT" 2539 ("Tue, 2 Jun 2020 16:25'
        ':29 +0200" "tested" (("Tallah" NIL "Rocks" "domain.com")) (("Tallah"'
        ' NIL "Rocks" "domain.com")) (("Tallah" NIL "Rocks" "domain.com")) '
        '(("Rocks@domain.com" NIL "Rocks" "domain.com")("Akari Haro" NIL "ak'
        'ari-haro" "domain.com")) NIL NIL NIL "GDQBjfh3TAG63B@domain.com") '
        '(("TEXT" "PLAIN" ("CHARSET" "utf8") NIL NIL "7BIT" 0 0 NIL NIL NIL)'
        '("TEXT" "HTML" ("CHARSET" "utf8") NIL NIL "8BIT" 1 1 NIL NIL NIL) "'
        'ALTERNATIVE" ("BOUNDARY" "C6WuYgfyNiVn6u" "CHARSET" "utf8") NIL NIL)'
        ' 51 NIL NIL NIL) "REPORT" ("BOUNDARY" "0000000000002f1f3705a71aaf47"'
        ' "REPORT-TYPE" "delivery-status") NIL NIL'
        ')'
        ')';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].uid, 3641);
    expect(messages[0].flags, ['\\Seen']);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartReport);
    expect(body.contentType!.boundary, '0000000000002f1f3705a71aaf47');
    expect(body.contentType!.parameters['report-type'], 'delivery-status');
    expect(body.parts, isNotNull);
    expect(body.parts!.length, 3);
    expect(body.parts![0].fetchId, '1');
    expect(body.parts![0].contentType, isNotNull);
    expect(body.parts![0].contentType!.mediaType, isNotNull);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartRelated);
    expect(
        body.parts![0].contentType!.boundary, '0000000000002f322205a71aaf68');
    expect(body.parts![0].parts, isNotNull);
    expect(body.parts![0].parts, isNotEmpty);
    expect(body.parts![0].parts!.length, 2);
    expect(body.parts![0].parts![0].contentType?.mediaType.top,
        MediaToptype.multipart);
    expect(body.parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![0].parts![0].contentType!.boundary,
        '0000000000002f322a05a71aaf69');
    expect(body.parts![0].parts![0].parts!.length, 2);
    expect(body.parts![0].parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![0].parts![0].parts![0].contentType?.charset, 'utf-8');
    expect(body.parts![0].parts![0].parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].parts![0].parts![0].size, 274);
    expect(body.parts![0].parts![0].parts![1].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![0].parts![0].parts![1].contentType?.charset, 'utf-8');
    expect(body.parts![0].parts![0].parts![1].encoding, 'quoted-printable');
    expect(body.parts![0].parts![0].parts![1].size, 1455);
    expect(body.parts![1].contentType, isNotNull);
    expect(body.parts![1].contentType!.mediaType, isNotNull);
    expect(body.parts![1].contentType!.mediaType.top, MediaToptype.message);
    expect(body.parts![1].contentType!.mediaType.sub,
        MediaSubtype.messageDeliveryStatus);
    expect(body.parts![1].size, 488);
    expect(body.parts![1].encoding, '7bit');
    expect(body.parts![2].contentType!.mediaType.top, MediaToptype.message);
    expect(
        body.parts![2].contentType!.mediaType.sub, MediaSubtype.messageRfc822);
    expect(body.parts![2].envelope, isNotNull);
    expect(body.parts![2].envelope!.subject, 'tested');
    expect(body.parts![2].envelope!.date,
        DateCodec.decodeDate('Tue, 2 Jun 2020 16:25:29 +0200'));
    expect(body.parts![2].envelope!.from?.length, 1);
    expect(body.parts![2].envelope!.from![0].email, 'Rocks@domain.com');
    expect(body.parts![2].envelope!.to?.length, 2);
    expect(body.parts![2].envelope!.to![0].email, 'Rocks@domain.com');
    expect(body.parts![2].envelope!.to![1].email, 'akari-haro@domain.com');
    expect(body.parts![2].envelope!.to![1].personalName, 'Akari Haro');
    expect(body.parts![2].parts?.length, 1);
    expect(body.parts![2].parts![0].contentType?.mediaType.top,
        MediaToptype.multipart);
    expect(body.parts![2].parts![0].contentType?.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![2].parts![0].contentType?.boundary, 'C6WuYgfyNiVn6u');
    expect(body.parts![2].parts![0].contentType?.charset, 'utf8');
    expect(body.parts![2].parts![0].parts?.length, 2);
    expect(body.parts![2].parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![2].parts![0].parts![0].contentType?.charset, 'utf8');
    expect(body.parts![2].parts![0].parts![0].encoding, '7bit');
    expect(body.parts![2].parts![0].parts![0].size, 0);
    expect(body.parts![2].parts![0].parts![1].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![2].parts![0].parts![1].contentType?.charset, 'utf8');
    expect(body.parts![2].parts![0].parts![1].encoding, '8bit');
    expect(body.parts![2].parts![0].parts![1].size, 1);
  });

  test('BODYSTRUCTURE 4 - single part', () {
    const responseTexts = [
      '''* 2175 FETCH (BODYSTRUCTURE ("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 1315 42 NIL NIL NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body.contentType!.mediaType.top, MediaToptype.text);
    expect(body.contentType!.charset, 'iso-8859-1');
    expect(body.encoding, 'quoted-printable');
    expect(body.size, 1315);
    expect(body.numberOfLines, 42);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 5 - simple alternative', () {
    const responseTexts = [
      '''* 1 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 2234 63 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "iso-8859-1") NIL NIL "QUOTED-PRINTABLE" 2987 52 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "d3438gr7324") NIL NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartAlternative);
    expect(body.contentType!.boundary, 'd3438gr7324');
    expect(body.parts?.length, 2);
    expect(body.parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType?.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![0].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].size, 2234);
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![1].contentType?.mediaType.sub, MediaSubtype.textHtml);
    expect(body.parts![1].contentType?.charset, 'iso-8859-1');
    expect(body.parts![1].encoding, 'quoted-printable');
    expect(body.parts![1].size, 2987);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 6 - simple alternative with image', () {
    const responseTexts = [
      '''* 335 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 119 2 NIL ("INLINE" NIL) NIL)("IMAGE" "JPEG" ("NAME" "4356415.jpg") "<0__=rhksjt>" NIL "BASE64" 143804 NIL ("INLINE" ("FILENAME" "4356415.jpg")) NIL) "RELATED" ("BOUNDARY" "0__=5tgd3d") ("INLINE" NIL) NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.contentType!.boundary, '0__=5tgd3d');
    // expect(body.contentDisposition, isNotNull);
    // expect(body.contentDisposition?.disposition, ContentDisposition.inline);
    expect(body.parts?.length, 2);
    expect(body.parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType?.mediaType.sub, MediaSubtype.textHtml);
    expect(body.parts![0].contentType?.charset, 'us-ascii');
    expect(body.parts![0].encoding, '7bit');
    expect(body.parts![0].size, 119);
    expect(body.parts![0].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.image);
    expect(body.parts![1].contentType?.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.parts![1].contentType?.parameters['name'], '4356415.jpg');
    expect(body.parts![1].encoding, 'base64');
    expect(body.parts![1].cid, '<0__=rhksjt>');
    expect(body.parts![1].size, 143804);
    expect(body.parts![1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts![1].contentDisposition?.filename, '4356415.jpg');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 7 - text + html with images', () {
    const responseTexts = [
      '''* 202 FETCH (BODYSTRUCTURE (("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1" "FORMAT" "flowed") NIL NIL "QUOTED-PRINTABLE" 2815 73 NIL NIL NIL NIL)(("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4171 66 NIL NIL NIL NIL)("IMAGE" "JPEG" ("NAME" "image.jpg") "<3245dsf7435>" NIL "BASE64" 189906 NIL NIL NIL NIL)("IMAGE" "GIF" ("NAME" "other.gif") "<32f6324f>" NIL "BASE64" 1090 NIL NIL NIL NIL) "RELATED" ("BOUNDARY" "--=sdgqgt") NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "--=u5sfrj") NIL NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartAlternative);
    expect(body.contentType!.boundary, '--=u5sfrj');
    expect(body.parts?.length, 2);
    expect(body.parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType?.mediaType.sub, MediaSubtype.textPlain);
    expect(body.parts![0].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].contentType?.isFlowedFormat, true);
    expect(body.parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].size, 2815);
    // expect(body.parts[0].contentDisposition?.disposition,
    //     ContentDisposition.inline);
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.multipart);
    expect(body.parts![1].contentType?.mediaType.sub,
        MediaSubtype.multipartRelated);
    expect(body.parts![1].contentType?.boundary, '--=sdgqgt');
    expect(body.parts![1].parts?.length, 3);
    expect(
        body.parts![1].parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![1].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![1].parts![0].contentType?.charset, 'iso-8859-1');
    expect(body.parts![1].parts![0].encoding, 'quoted-printable');
    expect(body.parts![1].parts![1].contentType?.mediaType.top,
        MediaToptype.image);
    expect(body.parts![1].parts![1].contentType?.mediaType.sub,
        MediaSubtype.imageJpeg);
    expect(
        body.parts![1].parts![1].contentType?.parameters['name'], 'image.jpg');
    expect(body.parts![1].parts![1].cid, '<3245dsf7435>');
    expect(body.parts![1].parts![1].encoding, 'base64');
    expect(body.parts![1].parts![1].size, 189906);
    expect(body.parts![1].parts![2].contentType?.mediaType.top,
        MediaToptype.image);
    expect(body.parts![1].parts![2].contentType?.mediaType.sub,
        MediaSubtype.imageGif);
    expect(
        body.parts![1].parts![2].contentType?.parameters['name'], 'other.gif');
    expect(body.parts![1].parts![2].cid, '<32f6324f>');
    expect(body.parts![1].parts![2].encoding, 'base64');
    expect(body.parts![1].parts![2].size, 1090);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 8 - text + html with images 2', () {
    const responseTexts = [
      '''* 41 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 471 28 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 1417 36 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "1__=hqjksdm") NIL NIL)("IMAGE" "GIF" ("NAME" "image.gif") "<1__=cxdf2f>" NIL "BASE64" 50294 NIL ("INLINE" ("FILENAME" "image.gif")) NIL) "RELATED" ("BOUNDARY" "0__=hqjksdm") NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.contentType!.boundary, '0__=hqjksdm');
    expect(body.parts?.length, 2);
    expect(body.parts![0].contentType?.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType?.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![0].contentType?.boundary, '1__=hqjksdm');
    expect(body.parts![0].parts?.length, 2);
    expect(
        body.parts![0].parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![0].parts![0].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].parts![0].size, 471);
    expect(
        body.parts![0].parts![1].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].parts![1].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![0].parts![1].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].parts![1].encoding, 'quoted-printable');
    expect(body.parts![0].parts![1].size, 1417);
    expect(body.parts![0].parts![1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.image);
    expect(body.parts![1].contentType?.mediaType.sub, MediaSubtype.imageGif);
    expect(body.parts![1].contentType?.parameters['name'], 'image.gif');
    expect(body.parts![1].cid, '<1__=cxdf2f>');
    expect(body.parts![1].encoding, 'base64');
    expect(body.parts![1].size, 50294);
    expect(body.parts![1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts![1].contentDisposition?.filename, 'image.gif');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 9 - mail with attachment', () {
    const responseTexts = [
      '''* 302 FETCH (BODYSTRUCTURE (("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 4692 69 NIL NIL NIL NIL)("APPLICATION" "PDF" ("NAME" "pages.pdf") NIL NIL "BASE64" 38838 NIL ("attachment" ("FILENAME" "pages.pdf")) NIL NIL) "MIXED" ("BOUNDARY" "----=6fgshr") NIL NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '----=6fgshr');
    expect(body.parts?.length, 2);
    expect(body.parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType?.mediaType.sub, MediaSubtype.textHtml);
    expect(body.parts![0].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].size, 4692);
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.application);
    expect(
        body.parts![1].contentType?.mediaType.sub, MediaSubtype.applicationPdf);
    expect(body.parts![1].contentType?.parameters['name'], 'pages.pdf');
    expect(body.parts![1].encoding, 'base64');
    expect(body.parts![1].size, 38838);
    expect(body.parts![1].contentDisposition?.disposition,
        ContentDisposition.attachment);
    expect(body.parts![1].contentDisposition?.filename, 'pages.pdf');
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 10 - alternative and attachment', () {
    const responseTexts = [
      '''* 356 FETCH (BODYSTRUCTURE ((("TEXT" "PLAIN" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 403 6 NIL NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "UTF-8") NIL NIL "QUOTED-PRINTABLE" 421 6 NIL NIL NIL NIL) "ALTERNATIVE" ("BOUNDARY" "----=fghgf3") NIL NIL NIL)("APPLICATION" "vnd.openxmlformats-officedocument.wordprocessingml.document" ("NAME" "letter.docx") NIL NIL "BASE64" 110000 NIL ("attachment" ("FILENAME" "letter.docx" "SIZE" "80384")) NIL NIL) "MIXED" ("BOUNDARY" "----=y34fgl") NIL NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '----=y34fgl');
    expect(body.parts?.length, 2);
    expect(body.parts![0].fetchId, '1');
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![0].contentType!.boundary, '----=fghgf3');
    expect(body.parts![0].parts?.length, 2);
    expect(body.parts![0].parts![0].fetchId, '1.1');
    expect(
        body.parts![0].parts![0].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![0].parts![0].contentType?.charset, 'utf-8');
    expect(body.parts![0].parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].parts![0].size, 403);
    expect(body.parts![0].parts![1].fetchId, '1.2');
    expect(
        body.parts![0].parts![1].contentType?.mediaType.top, MediaToptype.text);
    expect(body.parts![0].parts![1].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![0].parts![1].contentType?.charset, 'utf-8');
    expect(body.parts![0].parts![1].encoding, 'quoted-printable');
    expect(body.parts![0].parts![1].size, 421);
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.application);
    expect(body.parts![1].fetchId, '2');
    expect(body.parts![1].contentType?.mediaType.sub,
        MediaSubtype.applicationOfficeDocumentWordProcessingDocument);
    expect(body.parts![1].contentType?.parameters['name'], 'letter.docx');
    expect(body.parts![1].encoding, 'base64');
    expect(body.parts![1].size, 110000);
    expect(body.parts![1].contentDisposition?.disposition,
        ContentDisposition.attachment);
    expect(body.parts![1].contentDisposition?.filename, 'letter.docx');
    expect(body.parts![1].contentDisposition?.size, 80384);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 11 - all together', () {
    const responseTexts = [
      '''* 1569 FETCH (BODYSTRUCTURE (((("TEXT" "PLAIN" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 833 30 NIL NIL NIL)("TEXT" "HTML" ("CHARSET" "ISO-8859-1") NIL NIL "QUOTED-PRINTABLE" 3412 62 NIL ("INLINE" NIL) NIL) "ALTERNATIVE" ("BOUNDARY" "2__=fgrths") NIL NIL)("IMAGE" "GIF" ("NAME" "485039.gif") "<2__=lgkfjr>" NIL "BASE64" 64 NIL ("INLINE" ("FILENAME" "485039.gif")) NIL) "RELATED" ("BOUNDARY" "1__=fgrths") NIL NIL)("APPLICATION" "PDF" ("NAME" "title.pdf") "<1__=lgkfjr>" NIL "BASE64" 333980 NIL ("ATTACHMENT" ("FILENAME" "title.pdf")) NIL) "MIXED" ("BOUNDARY" "0__=fgrths") NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '0__=fgrths');
    expect(body.parts?.length, 2);
    expect(body.parts![0].fetchId, '1');
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartRelated);
    expect(body.parts![0].contentType!.boundary, '1__=fgrths');
    expect(body.parts![0].parts?.length, 2);
    expect(body.parts![0].parts![0].contentType!.mediaType.top,
        MediaToptype.multipart);
    expect(body.parts![0].parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![0].parts![0].contentType!.boundary, '2__=fgrths');
    expect(body.parts![0].parts![0].fetchId, '1.1');
    expect(body.parts![0].parts![0].parts?.length, 2);
    expect(body.parts![0].parts![0].parts![0].fetchId, '1.1.1');
    expect(body.parts![0].parts![0].parts![0].contentType?.mediaType.top,
        MediaToptype.text);
    expect(body.parts![0].parts![0].parts![0].contentType?.mediaType.sub,
        MediaSubtype.textPlain);
    expect(
        body.parts![0].parts![0].parts![0].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].parts![0].parts![0].encoding, 'quoted-printable');
    expect(body.parts![0].parts![0].parts![0].size, 833);
    expect(body.parts![0].parts![0].parts![1].fetchId, '1.1.2');
    expect(body.parts![0].parts![0].parts![1].contentType?.mediaType.top,
        MediaToptype.text);
    expect(body.parts![0].parts![0].parts![1].contentType?.mediaType.sub,
        MediaSubtype.textHtml);
    expect(
        body.parts![0].parts![0].parts![1].contentType?.charset, 'iso-8859-1');
    expect(body.parts![0].parts![0].parts![1].encoding, 'quoted-printable');
    expect(body.parts![0].parts![0].parts![1].size, 3412);
    expect(body.parts![0].parts![0].parts![1].contentDisposition?.disposition,
        ContentDisposition.inline);
    expect(body.parts![1].fetchId, '2');
    expect(body.parts![1].contentType?.mediaType.top, MediaToptype.application);
    expect(
        body.parts![1].contentType?.mediaType.sub, MediaSubtype.applicationPdf);
    expect(body.parts![1].contentType?.parameters['name'], 'title.pdf');
    expect(body.parts![1].encoding, 'base64');
    expect(body.parts![1].cid, '<1__=lgkfjr>');
    expect(body.parts![1].size, 333980);
    expect(body.parts![1].contentDisposition?.disposition,
        ContentDisposition.attachment);
    expect(body.parts![1].contentDisposition?.filename, 'title.pdf');
  });

  // real world example
  test('BODYSTRUCTURE 12 - real world example', () {
    const responseText = '* 1569 FETCH (BODYSTRUCTURE (('
        '("text" "plain" ("charset" "iso-8859-1") NIL NIL "quoted-printable"'
        ' 149 10 NIL NIL NIL NIL)'
        '("text" "html" ("charset" "iso-8859-1") NIL NIL "quoted-printable" '
        '2065 42 NIL NIL NIL NIL) "alternative" ("boundary" "_000_AM5PR0701'
        'MB25139B9E8D23795759E68308E8AD0AM5PR0701MB2513_") NIL NIL)'
        '("image" "jpeg" ("name" "20210109_113526.jpg") "<f198c712-36bc-4248'
        '-a165-44d5560c60af>" "20210109_113526.jpg" "base64" 3902340 NIL ("i'
        'nline" ("filename" "20210109_113526.jpg" "size" "2851709" "creation'
        '-date" "Sat, 09 Jan 2021 7:39:59 GMT" "modification-date" "Sat, 09 '
        'Jan 2021 10:39:59 GMT")) NIL NIL)'
        '("image" "jpeg" ("name" "20210109_113554.jpg") "<e2510834-f907-474'
        'b-822a-25f239818adc>" "20210109_113554.jpg" "base64" 5166380 NIL ("'
        'inline" ("filename" "20210109_113554.jpg" "size" "3775431" "creation'
        '-date" "Sat, 09 Jan 2021 7:40:40 GMT" "modification-date" "Sat, 09 J'
        'an 2021 7:40:40 GMT")) NIL NIL)'
        '("image" "jpeg" ("name" "20210109_113545.jpg") "<63441da1-6a9e-4afc-'
        'b13a-6ee3700e7fa7>" "20210109_113545.jpg" "base64" 4294472 NIL ("inl'
        'ine" ("filename" "20210109_113545.jpg" "size" "3138267" "creation-da'
        'te" "Sat, 09 Jan 2021 7:40:45 GMT" "modification-date" "Sat, 09 Jan '
        '2021 7:40:45 GMT")) NIL NIL)'
        '("image" "jpeg" ("name" "processed.jpeg") "<0756cb18-2a81-4bd1-a3af-'
        'b11816caf509>" "processed.jpeg" "base64" 306848 NIL ("inline" ("file'
        'name" "processed.jpeg" "size" "224235" "creation-date" "Sat, 09 Jan '
        '2021 7:41:25 GMT" "modification-date" "Sat, 09 Jan 2021 7:41:25 GMT"'
        ')) NIL NIL)'
        ' "related" ("boundary" "_007_AM5PR0701MB25139B9E8D23795759E68308E8AD'
        '0AM5PR0701MB2513_" "type" "multipart/alternative") NIL "de-DE") UID'
        ' 1234567)';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartRelated);
    expect(body.contentType!.boundary,
        '_007_AM5PR0701MB25139B9E8D23795759E68308E8AD0AM5PR0701MB2513_');
    expect(body.parts?.length, 5);
    expect(body.parts![1].cid, '<f198c712-36bc-4248-a165-44d5560c60af>');
    expect(body.parts![2].cid, '<e2510834-f907-474b-822a-25f239818adc>');
    expect(body.parts![3].cid, '<63441da1-6a9e-4afc-b13a-6ee3700e7fa7>');
    expect(body.parts![4].cid, '<0756cb18-2a81-4bd1-a3af-b11816caf509>');

    expect(body.parts![0].fetchId, '1');
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.parts![0].contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body.parts![0].contentType!.boundary,
        '_000_AM5PR0701MB25139B9E8D23795759E68308E8AD0AM5PR0701MB2513_');
    expect(body.parts![0].parts?.length, 2);
    expect(
        body.parts![0].parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].parts![0].contentType!.mediaType.sub,
        MediaSubtype.textPlain);
    expect(body.parts![0].parts![1].contentType!.mediaType.sub,
        MediaSubtype.textHtml);
    expect(body.parts![0].parts![0].contentType!.boundary, null);
  });

  // source: http://sgerwk.altervista.org/imapbodystructure.html
  test('BODYSTRUCTURE 13 - single-element lists', () {
    const responseTexts = [
      '''* 2246 FETCH (BODYSTRUCTURE (("TEXT" "HTML" NIL NIL NIL "7BIT" 151 0 NIL NIL NIL) "MIXED" ("BOUNDARY" "----=rfsewr") NIL NIL))'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body!;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '----=rfsewr');
    expect(body.parts?.length, 1);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType!.mediaType.sub, MediaSubtype.textHtml);
    expect(body.parts![0].encoding, '7bit');
    expect(body.parts![0].size, 151);
    expect(body.parts![0].fetchId, '1');
  });

  test('BODYSTRUCTURE 14 - with raw data parameters', () {
    final contentType = ContentTypeHeader('application/pdf')
      ..setParameter('name', 'FileName.pdf');
    expect(contentType.parameters['name'], 'FileName.pdf');
    final contentDisposition = ContentDispositionHeader('attachment')
      ..setParameter('filename', 'FileName.pdf');
    expect(contentDisposition.filename, 'FileName.pdf');
    const line1 =
        '* 63644 FETCH (UID 351739 BODYSTRUCTURE (("TEXT" "html" ("charset" '
        '"utf-8") NIL NIL "BASE64" 5234 68 NIL NIL NIL NIL)("APPLICATION" "pdf"'
        ' ("name" "Testpflicht an Schulen_09_04_21.pdf") NIL NIL "BASE64" '
        '638510'
        ' NIL ("attachment" ("filename" "Testpflicht an Schulen_09_04_21.pdf" '
        '"size" "466602")) NIL NIL)("APPLICATION" "pdf" ("name" {42}';
    const line2 = 'Schnelltest Einverständniserklärung3.pdf';
    const line3 = ') NIL NIL "7BIT" 239068 NIL ("attachment" ("filename" {42}';
    const line4 = 'Schnelltest Einverständniserklärung3.pdf';
    const line5 =
        '"size" "174701")) NIL NIL) "mixed" ("boundary" "--_com.android.email_'
        '1204848368992460") NIL NIL NIL))';
    const responseTexts = [line1, line2, line3, line4, line5];
    final details = ImapResponse();
    var lastLineEndedInData = false;
    for (final text in responseTexts) {
      if (lastLineEndedInData) {
        final rawData = utf8.encode(text);
        details.add(ImapResponseLine.raw(rawData));
        lastLineEndedInData = false;
      } else {
        details.add(ImapResponseLine(text));
        lastLineEndedInData = text.endsWith('}');
      }
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body;
    //print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body!.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '--_com.android.email_1204848368992460');
    expect(body.parts?.length, 3);
    expect(body.parts![0].contentType!.mediaType.top, MediaToptype.text);
    expect(body.parts![0].contentType!.mediaType.sub, MediaSubtype.textHtml);
    expect(body.parts![0].encoding, 'base64');
    expect(body.parts![0].size, 5234);
    expect(
        body.parts![1].contentType!.mediaType.sub, MediaSubtype.applicationPdf);
    expect(body.parts![1].contentType!.parameters['name'],
        'Testpflicht an Schulen_09_04_21.pdf');
    expect(body.parts![1].contentDisposition, isNotNull);
    expect(body.parts![1].contentDisposition!.disposition,
        ContentDisposition.attachment);
    expect(body.parts![1].contentDisposition!.filename,
        'Testpflicht an Schulen_09_04_21.pdf');
    expect(body.parts![1].contentDisposition!.size, 466602);

    expect(
        body.parts![2].contentType!.mediaType.sub, MediaSubtype.applicationPdf);
    expect(body.parts![2].contentType!.parameters['name'],
        'Schnelltest Einverständniserklärung3.pdf');
    expect(body.parts![2].contentDisposition, isNotNull);
    expect(body.parts![2].contentDisposition!.disposition,
        ContentDisposition.attachment);
    expect(body.parts![2].contentDisposition!.filename,
        'Schnelltest Einverständniserklärung3.pdf');
    expect(body.parts![2].contentDisposition!.size, 174701);
  });

  test('BODYSTRUCTURE 15 - complex with nested messages', () {
    const responseText =
        '''* 42780 FETCH (UID 147491 BODYSTRUCTURE (("TEXT" "plain" ("charset" "utf-8" "format" "flowed") NIL NIL "7BIT" 18 2 NIL NIL NIL NIL)("MESSAGE" "RFC822" ("name" "hello.eml") NIL NIL "7BIT" 198569 ("Wed, 14 Apr 2021 15:21:39 +0200" "hello" (("Laura Z" NIL "laura" "domain.com")) (("Laura Z" NIL "laura" "domain.com")) (("Laura Z" NIL "laura" "domain.com")) (("Robert" NIL "robert" "domain.org")) NIL NIL NIL "<A6741A9D-E6EE-4F2B-84CD-7575867C0915@domain.com>") (("TEXT" "plain" ("charset" "utf-8") NIL NIL "QUOTED-PRINTABLE" 428 29 NIL NIL NIL NIL)(("TEXT" "html" ("charset" "utf-8") NIL NIL "QUOTED-PRINTABLE" 7306 106 NIL NIL NIL NIL)("APPLICATION" "pdf" ("name" "document.pdf" "x-unix-mode" "0644") NIL NIL "BASE64" 184654 NIL ("inline" ("filename" "document.pdf")) NIL NIL)("TEXT" "html" ("charset" "us-ascii") NIL NIL "7BIT" 206 1 NIL NIL NIL NIL) "mixed" ("boundary" "Apple-Mail=_906E0701-F4B8-4A94-8CBA-E942B0E83C3D") NIL NIL NIL) "alternative" ("boundary" "Apple-Mail=_0818BF02-C6EC-4C85-ABD0-2A7CD6D0C178") NIL NIL NIL) 2619 NIL ("attachment" ("filename" "hello.eml")) NIL NIL)("MESSAGE" "RFC822" ("name" "Re: Foto test.eml") NIL NIL "7BIT" 813742 ("Thu, 15 Apr 2021 20:34:20 +0200" "Re: Foto test" (("Olga Z" NIL "sender" "domain.org")) (("Olga Z" NIL "sender" "domain.org")) (("Olga Z" NIL "sender" "domain.org")) (("Robert" NIL "robert" "domain.org")) NIL NIL "<1KxaI8FSujPYUDr_-0@domain.org>" "<6EJedHRKJ5sYJqjyqv@domain.org>") ((("TEXT" "plain" ("charset" "utf8") NIL NIL "QUOTED-PRINTABLE" 857 23 NIL NIL NIL NIL)("TEXT" "html" ("charset" "utf8") NIL NIL "QUOTED-PRINTABLE" 1252 35 NIL NIL NIL NIL) "alternative" ("boundary" "j2cHqGO6QhvyRZOtse") NIL NIL NIL)("IMAGE" "jpeg" ("name" "Screenshot_20210415-191139.jpg") NIL NIL "BASE64" 807126 NIL ("attachment" ("filename" "Screenshot_20210415-191139.jpg" "size" "589824")) NIL NIL) "mixed" ("boundary" "f44yw2ALkRvC4xc9Xm") NIL NIL NIL) 10490 NIL ("attachment" ("filename" "Re: Foto test.eml")) NIL NIL) "mixed" ("boundary" "------------511076DDA2208D9767CA39EA") NIL "en-US" NIL))''';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    final body = messages[0].body;
    // print('parsed body part: \n$body');
    expect(body, isNotNull);
    expect(body!.contentType, isNotNull);
    expect(body.contentType!.mediaType, isNotNull);
    expect(body.contentType!.mediaType.top, MediaToptype.multipart);
    expect(body.contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body.contentType!.boundary, '------------511076DDA2208D9767CA39EA');
    expect(body.length, 3);
    expect(body[0].contentType!.mediaType.top, MediaToptype.text);
    expect(body[0].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(body[0].encoding, '7bit');
    expect(body[0].size, 18);
    expect(body[0].fetchId, '1');
    expect(body[1].fetchId, '2');
    expect(body[1].contentType, isNotNull);
    expect(body[1].contentType!.mediaType.sub, MediaSubtype.messageRfc822);
    expect(body[1].contentType!.parameters['name'], 'hello.eml');
    expect(body[1].contentDisposition, isNotNull);
    expect(
        body[1].contentDisposition!.disposition, ContentDisposition.attachment);
    expect(body[1].contentDisposition!.filename, 'hello.eml');
    expect(body[1].length, 1);
    expect(body[1][0].contentType, isNotNull);
    expect(body[1][0].contentType!.mediaType.sub,
        MediaSubtype.multipartAlternative);
    expect(body[1].fetchId, '2');
    expect(body[1][0].fetchId, '2.TEXT');
    expect(body[1][0].length, 2);
    expect(body[1][0][0].fetchId, '2.TEXT.1');
    expect(body[1][0][0].contentType, isNotNull);
    expect(body[1][0][0].contentType!.mediaType.sub, MediaSubtype.textPlain);
    expect(
        body[1][0][1].contentType!.mediaType.sub, MediaSubtype.multipartMixed);
    expect(body[2].fetchId, '3');
    expect(body[2][0].fetchId, '3.TEXT');

    final leafParts = body.allLeafParts;
    expect(leafParts.length, 8);
    expect(leafParts[0].contentType?.mediaType.sub, MediaSubtype.textPlain);
    expect(leafParts[1].contentType?.mediaType.sub, MediaSubtype.textPlain);
    expect(leafParts[2].contentType?.mediaType.sub, MediaSubtype.textHtml);
    expect(
        leafParts[3].contentType?.mediaType.sub, MediaSubtype.applicationPdf);
    expect(leafParts[4].contentType?.mediaType.sub, MediaSubtype.textHtml);
    expect(leafParts[5].contentType?.mediaType.sub, MediaSubtype.textPlain);
    expect(leafParts[6].contentType?.mediaType.sub, MediaSubtype.textHtml);
    expect(leafParts[7].contentType?.mediaType.sub, MediaSubtype.imageJpeg);
  });

  test('MODSEQ', () {
    const responseText = '* 50 FETCH (MODSEQ (12111230047))';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].sequenceId, 50);
    expect(messages[0].modSequence, 12111230047);
  });

  test('HIGHESTMODSEQ', () {
    const responseText = '* OK [HIGHESTMODSEQ 12111230047]';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, false);
  });

  test('VANISHED', () {
    const responseText = '* VANISHED (EARLIER) 300:310,405,411';
    final details = ImapResponse()..add(ImapResponseLine(responseText));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);

    expect(processed, true);
    expect(parser.lastParsedMessage, isNull);
    expect(parser.vanishedMessages, isNotNull);
    expect(parser.vanishedMessages!.toList(),
        [300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 405, 411]);
    final result = parser.parse(details, response)!;
    expect(result.messages, isEmpty);
    expect(result.vanishedMessagesUidSequence, isNotNull);
    expect(result.vanishedMessagesUidSequence!.toList(),
        [300, 301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 405, 411]);
  });

  test('BODY[2.1]', () {
    const responseText1 = '* 50 FETCH (BODY[2.1] {12}';
    const responseText2 = 'Hello Word\r\n';
    const responseText3 = ')';

    final details = ImapResponse()
      ..add(ImapResponseLine(responseText1))
      ..add(ImapResponseLine.raw(utf8.encode(responseText2)))
      ..add(ImapResponseLine(responseText3));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response)!;
    expect(result.messages, isNotEmpty);
    expect(result.messages.length, 1);
    final part = result.messages[0].getPart('2.1');
    expect(part, isNotNull);
    expect(part!.decodeContentText(), 'Hello Word\r\n');
  });

  test('empty BODY[2.1]', () {
    const responseText1 = '* 50 FETCH (BODY[2.1] {0}';
    const responseText3 = ')';

    final details = ImapResponse()
      ..add(ImapResponseLine(responseText1))
      ..add(ImapResponseLine.raw(Uint8List(0)))
      ..add(ImapResponseLine(responseText3));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final result = parser.parse(details, response)!;
    expect(result.messages, isNotEmpty);
    expect(result.messages.length, 1);
    final part = result.messages[0].getPart('2.1');
    expect(part, isNotNull);
    expect(part!.decodeContentText(), '');
  });

  test('ENVELOPE 1', () {
    const responseTexts = [
      r'* 61792 FETCH (UID 347524 RFC822.SIZE 4579 ENVELOPE ("Sun, 9 Aug 2020 09:03:12 +0200 (CEST)" "Re: Your Query" (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) ((NIL NIL "recipient" "enough.de")) NIL NIL NIL "<9jbzp5olgc9n54qwutoty0pnxunmoyho5ugshxplpvudvurjwh3a921kjdwkpwrf9oe06g95k69t@mail.ebay-kleinanzeigen.de>") FLAGS (\Seen))'
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].uid, 347524);
    expect(messages[0].size, 4579);
    expect(messages[0].flags, ['\\Seen']);
    expect(messages[0].from, isNotNull);
    expect(messages[0].from!.length, 1);
    expect(messages[0].from![0].email,
        'anbieter-sdkjskjfkd@mail.ebay-kleinanzeigen.de');
    expect(
        messages[0].from![0].personalName, 'C. Sender über eBay Kleinanzeigen');
    expect(messages[0].decodeSubject(), 'Re: Your Query');
  });

  test('ENVELOPE 2 with escaped quote in subject', () {
    const responseTexts = [
      r'* 61792 FETCH (UID 347524 RFC822.SIZE 4579 ENVELOPE ("Sun, 9 Aug 2020 09:03:12 +0200 (CEST)" "Re: Your Query about \"Table\"" (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) ((NIL NIL "recipient" "enough.de")) NIL NIL NIL "<9jbzp5olgc9n54qwutoty0pnxunmoyho5ugshxplpvudvurjwh3a921kjdwkpwrf9oe06g95k69t@mail.ebay-kleinanzeigen.de>") FLAGS (\Seen))'
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].uid, 347524);
    expect(messages[0].size, 4579);
    expect(messages[0].flags, ['\\Seen']);
    expect(messages[0].decodeSubject(), 'Re: Your Query about "Table"');
    expect(messages[0].from, isNotNull);
    expect(messages[0].from!.length, 1);
    expect(messages[0].from![0].email,
        'anbieter-sdkjskjfkd@mail.ebay-kleinanzeigen.de');
    expect(
        messages[0].from![0].personalName, 'C. Sender über eBay Kleinanzeigen');
  });

  test('ENVELOPE 3 with base64 in subject', () {
    const responseTexts = [
      '''* 43792 FETCH (UID 146616 RFC822.SIZE 23156 ENVELOPE ("Tue, 12 Jan 2021 00:18:08 +0800" " =?utf-8?B?SWbCoEnCoGhhdmXCoHRoZcKgaG9ub3LCoHRvwqBqb2luwqB5b3VywqB2ZW5kb3LCoGFzwqBhwqB0cmFuc2xhdGlvbsKgY29tcGFueQ==?=" (("Sherry|Company" NIL "company" "domain.com")) (("Sherry|Company" NIL "company" "domain.com")) ((NIL NIL "company" "domain.com")) (("info" NIL "info" "recipientdomain.com")) NIL NIL NIL " <ME2PR01MB2580191B6AA417095EEFD01FAEAB0@ME2PR01MB2580.ausprd01.prod.outlook.com>") FLAGS ())'''
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].decodeSubject(),
        ' If I have the honor to join your vendor as a translation company');
    expect(messages[0].uid, 146616);
    expect(messages[0].size, 23156);
    expect(messages[0].flags, []);
    expect(messages[0].from, isNotNull);
    expect(messages[0].from!.length, 1);
    expect(messages[0].from![0].email, 'company@domain.com');
    expect(messages[0].from![0].personalName, 'Sherry|Company');
  });

  test('ENVELOPE 4 with linebreak in subject', () {
    final details = ImapResponse()
      ..add(ImapResponseLine(
          '''* 65300 FETCH (UID 355372 ENVELOPE ("Sat, 13 Nov 2021 09:01:57 +0100 (CET)" {108}'''))
      ..add(ImapResponseLine.raw(utf8
          .encode('''=?UTF-8?Q?Anzeige_"K=C3=BCchenutensilien,_K=C3=A4seme?=\r
 =?UTF-8?Q?sser"_erfolgreich_ver=C3=B6ffentlicht.?=''')))
      ..add(ImapResponseLine(
          ''' (("eBay Kleinanzeigen" NIL "noreply" "ebay-kleinanzeigen.de")) (("eBay Kleinanzeigen" NIL "noreply" "ebay-kleinanzeigen.de")) (("eBay Kleinanzeigen" NIL "noreply" "ebay-kleinanzeigen.de")) ((NIL NIL "some.one" "domain.com")) NIL NIL NIL "<709648757.77104.1636790517873@tns-consumer-app-7.tns-consumer-app.ebayk.svc.cluster.local>"))'''));
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].decodeSubject(),
        'Anzeige "Küchenutensilien, Käsemesser" erfolgreich veröffentlicht.');
  });

  test('ENVELOPE 5 with base-encoded personal name in email', () {
    const responseTexts = [
      '''* 69457 FETCH (UID 366113 RFC822.SIZE 67087 ENVELOPE ("Tue, 26 Sep 2023 10:37:26 -0400" "New Release: Modernize Applications Faster Than Ever" (("=?utf-8?b?VGhl4oCvVGVsZXJpayAm4oCvS2VuZG8gVUk=?= =?utf-8?b?IFRlYW1z4oCvYXQgUHJvZ3Jlc3PigK8=?=" NIL "progress" "products.progress.com")) (("=?utf-8?b?VGhl4oCvVGVsZXJpayAm4oCvS2VuZG8gVUk=?= =?utf-8?b?IFRlYW1z4oCvYXQgUHJvZ3Jlc3PigK8=?=" NIL "progress" "products.progress.com")) (("=?utf-8?b?VGhl4oCvVGVsZXJpayAm4oCvS2VuZG8gVUk=?= =?utf-8?b?IFRlYW1z4oCvYXQgUHJvZ3Jlc3PigK8=?=" NIL "replytosales" "progress.com")) ((NIL NIL "robert.virkus" "enough.de")) NIL NIL NIL "<af7c35c283434b6f90fd8ba6820e35c2@1325>") FLAGS (\Seen))''',
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final processed = parser.parseUntagged(details, response);
    expect(processed, true);
    final messages = parser.parse(details, response)!.messages;
    expect(messages, isNotNull);
    expect(messages.length, 1);
    expect(messages[0].decodeSubject(),
        'New Release: Modernize Applications Faster Than Ever');
    expect(messages[0].uid, 366113);
    expect(messages[0].size, 67087);
    expect(messages[0].flags, ['Seen']);
    expect(messages[0].from, isNotNull);
    expect(messages[0].from!.length, 1);
    expect(messages[0].from![0].email, 'progress@products.progress.com');
    expect(
      messages[0].from![0].personalName,
      'The Telerik & Kendo UI Teams at Progress ',
    );
  });

  test('measure performance', () {
    const responseTexts = [
      r'* 61792 FETCH (UID 347524 RFC822.SIZE 4579 ENVELOPE ("Sun, 9 Aug 2020 09:03:12 +0200 (CEST)" "Re: Your Query about \"Table\"" (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) (("=?ISO-8859-1?Q?C=2E_Sender_=FCber_eBay_Kleinanzeigen?=" NIL "anbieter-sdkjskjfkd" "mail.ebay-kleinanzeigen.de")) ((NIL NIL "recipient" "enough.de")) NIL NIL NIL "<9jbzp5olgc9n54qwutoty0pnxunmoyho5ugshxplpvudvurjwh3a921kjdwkpwrf9oe06g95k69t@mail.ebay-kleinanzeigen.de>") FLAGS (\Seen))'
    ];
    final details = ImapResponse();
    for (final text in responseTexts) {
      details.add(ImapResponseLine(text));
    }
    final parser = FetchParser(isUidFetch: false);
    final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
    final stopwatch = Stopwatch()..start();
    for (var i = 10000; --i >= 0;) {
      final processed = parser.parseUntagged(details, response);
      if (!processed) {
        fail('unable to parse during performance test at round $i');
      }
    }
    //print('elapsed time: ${stopwatch.elapsedMicroseconds}');
    stopwatch.stop();
  });

  group('8bit encoding tests', () {
    test('Simple text message - windows-1252', () {
      final details = ImapResponse();
      const codec = Windows1252Codec();
      const messageText = '''Subject: Hello world\r
Content-Type: text/plain; charset=windows-1252; format=flowed\r
Content-Transfer-Encoding: 8bit\r
\r
Teší ma, že vás spoznávam!\r
''';
      final codecData = codec.encode(messageText);
      final messageData = Uint8List.fromList(codecData);
      details
        ..add(ImapResponseLine(
            '* 61792 FETCH (UID 347524  BODY[] {${messageData.length}}'))
        ..add(ImapResponseLine.raw(messageData))
        ..add(ImapResponseLine(')'));

      final parser = FetchParser(isUidFetch: false);
      final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
      final processed = parser.parseUntagged(details, response);
      expect(processed, true);
      final messages = parser.parse(details, response)!.messages;
      expect(messages, isNotNull);
      expect(messages.length, 1);
      expect(messages[0].decodeSubject(), 'Hello world');
      expect(messages[0].uid, 347524);
      expect(messages[0].sequenceId, 61792);
      expect(messages[0].decodeContentText(), 'Teší ma, že vás spoznávam!\r\n');
    });

    test('Multipart text message - windows-1252', () {
      final details = ImapResponse();
      const codec = Windows1252Codec();
      const messageText = '''Subject: Hello world\r
Content-Type: multipart/alternative; boundary=abcdefghijkl\r
\r
--abcdefghijkl\r
Content-Type: text/plain; charset=windows-1252; format=flowed\r
Content-Transfer-Encoding: 8bit\r
\r
Teší ma, že vás spoznávam!\r
--abcdefghijkl\r
Content-Type: text/html; charset=windows-1252\r
Content-Transfer-Encoding: 8bit\r
\r
<p>Teší ma, že vás spoznávam!</p>\r
--abcdefghijkl--\r
''';
      final codecData = codec.encode(messageText);
      final messageData = Uint8List.fromList(codecData);
      details
        ..add(ImapResponseLine(
            '* 61792 FETCH (UID 347524  BODY[] {${messageData.length}}'))
        ..add(ImapResponseLine.raw(messageData))
        ..add(ImapResponseLine(')'));

      final parser = FetchParser(isUidFetch: false);
      final response = Response<FetchImapResult>()..status = ResponseStatus.ok;
      final processed = parser.parseUntagged(details, response);
      expect(processed, true);
      final messages = parser.parse(details, response)!.messages;
      expect(messages, isNotNull);
      expect(messages.length, 1);
      expect(messages[0].headers, isNotNull);
      expect(messages[0].headers!.isNotEmpty, isTrue);
      expect(messages[0].headers, isNotNull);
      expect(messages[0].headers!.isNotEmpty, isTrue);
      expect(messages[0].headers!.length, 2);
      expect(messages[0].decodeSubject(), 'Hello world');
      expect(messages[0].uid, 347524);
      expect(messages[0].sequenceId, 61792);
      expect(
          messages[0].decodeTextPlainPart(), 'Teší ma, že vás spoznávam!\r\n');
      expect(messages[0].decodeTextHtmlPart(),
          '<p>Teší ma, že vás spoznávam!</p>\r\n');
    });
  });
}
