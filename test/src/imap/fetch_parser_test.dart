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
    expect(body.structures, isNotNull);
    expect(body.structures.length, 2);
    expect(body.structures[0].contentType, isNotNull);
    expect(body.structures[0].contentType.mediaType, isNotNull);
    expect(body.structures[0].contentType.mediaType.top, MediaToptype.text);
    expect(
        body.structures[0].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.structures[0].size, 45);
    expect(body.structures[0].numberOfLines, 3);
    expect(body.structures[0].contentType.charset, 'utf8');
    expect(body.structures[1].contentType.mediaType.top, MediaToptype.image);
    expect(
        body.structures[1].contentType.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.structures[1].contentType.parameters['name'], 'testimage.jpg');
    expect(body.structures[1].size, 18324);
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
    expect(body.structures, isNotNull);
    expect(body.structures.length, 2);
    expect(body.structures[0].contentType, isNotNull);
    expect(body.structures[0].contentType.mediaType, isNotNull);
    expect(body.structures[0].contentType.charset, 'us-ascii');
    expect(body.structures[0].contentType.mediaType.top, MediaToptype.text);
    expect(
        body.structures[0].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.structures[0].size, 1152);
    expect(body.structures[0].numberOfLines, 23);
    expect(body.structures[0].encoding, '7BIT');
    expect(body.structures[1].description, 'Compiler diff');
    expect(body.structures[1].id, '<960723163407.20117h@cac.washington.edu>');
    expect(body.structures[1].contentType.charset, 'us-ascii');
    expect(body.structures[1].contentType.parameters['name'], 'cc.diff');

    expect(body.structures[1].contentType.mediaType.top, MediaToptype.text);
    expect(
        body.structures[1].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.structures[1].size, 4554);
    expect(body.structures[1].numberOfLines, 73);
    expect(body.structures[1].encoding, 'BASE64');
    expect(body.contentType.mediaType.sub, MediaSubtype.multipartMixed);
  });

  test('BODYSTRUCTURE', () {
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
    expect(body.structures, isNotNull);
    expect(body.structures.length, 2);
    expect(body.structures[0].contentType, isNotNull);
    expect(body.structures[0].contentType.mediaType, isNotNull);
    expect(body.structures[0].contentType.mediaType.top, MediaToptype.text);
    expect(
        body.structures[0].contentType.mediaType.sub, MediaSubtype.textPlain);
    expect(body.structures[0].contentType.charset, 'utf8');
    expect(body.structures[0].contentDisposition, isNull);
    expect(body.structures[1].contentType.mediaType.top, MediaToptype.image);
    expect(
        body.structures[1].contentType.mediaType.sub, MediaSubtype.imageJpeg);
    expect(body.structures[1].contentType.parameters['name'], 'testimage.jpg');
    expect(body.structures[1].encoding, 'base64');
    var contentDisposition = body.structures[1].contentDisposition;
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
