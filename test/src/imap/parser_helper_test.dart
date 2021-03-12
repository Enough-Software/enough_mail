import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:test/test.dart';

void main() {
  test('ParserHelper.readNextWord', () {
    var input = 'HELLO ()';
    expect(ParserHelper.readNextWord(input, 0)!.text, 'HELLO');
    input = ' HELLO ()';
    expect(ParserHelper.readNextWord(input, 0)!.text, 'HELLO');
    expect(ParserHelper.readNextWord(input, 1)!.text, 'HELLO');
    input = ' HELLO () ENVELOPE (...)';
    expect(ParserHelper.readNextWord(input, 9)!.text, 'ENVELOPE');
    expect(ParserHelper.readNextWord(input, 10)!.text, 'ENVELOPE');
    input = ' HELLO () ENVELOPE';
    expect(ParserHelper.readNextWord(input, 9), null);
    expect(ParserHelper.readNextWord(input, 10), null);
    input = '   ';
    expect(ParserHelper.readNextWord(input, 0), null);
    input = ' ';
    expect(ParserHelper.readNextWord(input, 0), null);
    input = '';
    expect(ParserHelper.readNextWord(input, 0), null);
  }); // test end

  test('ParserHelper.parseHeader', () {
    var headerText = 'Return-Path: <marie.curie@domain.com>\r\n'
        'Delivered-To: jane.goodall@domain.com\r\n'
        'Received: from mx2.domain.com ([10.20.30.2])\r\n'
        '        by imap.domain.com with LMTP\r\n'
        '        id QOW0G8YmFl5tPAAA3c6Kzw\r\n'
        '        (envelope-from <marie.curie@domain.com>)\r\n'
        '        for <jane.goodall@domain.com>; Wed, 08 Jan 2020 20:00:22 +0100\r\n'
        'Received: from localhost (localhost.localdomain [127.0.0.1])\r\n'
        '        by mx2.domain.com (Postfix) with ESMTP id 5803D6A254\r\n'
        '        for <jane.goodall@domain.com>; Wed,  8 Jan 2020 20:00:22 +0100 (CET)\r\n';
    var result = ParserHelper.parseHeader(headerText);
    var headers = result.headersList;
    expect(result, isNotNull);
    expect(headers.length, 4);
    expect(headers[0].name, 'Return-Path');
    expect(headers[1].name, 'Delivered-To');
    expect(headers[2].name, 'Received');
    expect(headers[2].value,
        'from mx2.domain.com ([10.20.30.2]) by imap.domain.com with LMTP id QOW0G8YmFl5tPAAA3c6Kzw (envelope-from <marie.curie@domain.com>) for <jane.goodall@domain.com>; Wed, 08 Jan 2020 20:00:22 +0100');
    expect(headers[3].name, 'Received');
  });

  test('ParserHelper.parseHeader with body', () {
    var headerText = 'Return-Path: <marie.curie@domain.com>\r\n'
        'Delivered-To: jane.goodall@domain.com\r\n'
        'Received: from mx2.domain.com ([10.20.30.2])\r\n'
        '        by imap.domain.com with LMTP\r\n'
        '        id QOW0G8YmFl5tPAAA3c6Kzw\r\n'
        '        (envelope-from <marie.curie@domain.com>)\r\n'
        '        for <jane.goodall@domain.com>; Wed, 08 Jan 2020 20:00:22 +0100\r\n'
        'Received: from localhost (localhost.localdomain [127.0.0.1]) \r\n'
        '        by mx2.domain.com (Postfix) with ESMTP id 5803D6A254 \r\n'
        '        for <jane.goodall@domain.com>; Wed,  8 Jan 2020 20:00:22 +0100 (CET)\r\n'
        'Content-Type: text/plain\r\n'
        '\r\n'
        'Hello world.\r\n';
    var result = ParserHelper.parseHeader(headerText);
    var headers = result.headersList;
    expect(headers.length, 5);
    expect(headers[0].name, 'Return-Path');
    expect(headers[1].name, 'Delivered-To');
    expect(headers[2].name, 'Received');
    expect(headers[2].value,
        'from mx2.domain.com ([10.20.30.2]) by imap.domain.com with LMTP id QOW0G8YmFl5tPAAA3c6Kzw (envelope-from <marie.curie@domain.com>) for <jane.goodall@domain.com>; Wed, 08 Jan 2020 20:00:22 +0100');
    expect(headers[3].name, 'Received');
    expect(headers[4].name, 'Content-Type');
    expect(headers[4].value, 'text/plain');
    expect(result.bodyStartIndex != null, true);
    expect(headerText.substring(result.bodyStartIndex!), 'Hello world.\r\n');
  });

  test('ParserHelper.parseListEntries', () {
    var input = 'OK [MODIFIED 7,9] Conditional STORE failed';
    var textEntries = ParserHelper.parseListEntries(
        input, input.indexOf('[MODIFIED ') + '[MODIFIED '.length, ']', ',')!;
    expect(textEntries, isNotNull);
    expect(textEntries.length, 2);
    expect(textEntries[0], '7');
    expect(textEntries[1], '9');
    var intEntries = ParserHelper.parseListIntEntries(
        input, input.indexOf('[MODIFIED ') + '[MODIFIED '.length, ']', ',');
    expect(intEntries, isNotNull);
    expect(intEntries.length, 2);
    expect(intEntries[0], 7);
    expect(intEntries[1], 9);
  });
}
