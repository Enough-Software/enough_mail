import 'dart:convert';

import 'package:enough_mail/src/imap/namespace.dart';
import 'package:enough_mail/src/imap/response.dart';
import 'package:enough_mail/src/private/imap/imap_response.dart';
import 'package:enough_mail/src/private/imap/imap_response_line.dart';
import 'package:enough_mail/src/private/imap/namespace_parser.dart';
import 'package:test/test.dart';

// cSpell:disable

/// Parses [lines] the way the client hands them to the parser: the first
/// element is the text line, a following element after a literal is the
/// literal's bytes.
NamespaceResponse? parse(List<String> lines) {
  final details = ImapResponse();
  var literal = false;
  for (final line in lines) {
    if (literal) {
      details.add(ImapResponseLine.raw(utf8.encode(line)));
      literal = false;
    } else {
      final responseLine = ImapResponseLine(line);
      details.add(responseLine);
      literal = responseLine.isWithLiteral;
    }
  }
  final parser = NamespaceParser();
  final response = Response<NamespaceResponse?>()..status = ResponseStatus.ok;
  final processed = parser.parseUntagged(details, response);

  return processed ? parser.parse(details, response) : null;
}

void main() {
  // The examples are taken verbatim from RFC 2342 section 5.
  test('5.1 single personal namespace', () {
    final result = parse(['* NAMESPACE (("" "/")) NIL NIL'])!;
    expect(result.personal.length, 1);
    expect(result.personal[0].prefix, '');
    expect(result.personal[0].delimiter, '/');
    expect(result.otherUsers, isEmpty);
    expect(result.shared, isEmpty);
  });

  test('5.2 anonymous user, shared namespace only', () {
    final result = parse(['* NAMESPACE NIL NIL (("" "."))'])!;
    expect(result.personal, isEmpty);
    expect(result.otherUsers, isEmpty);
    expect(result.shared.length, 1);
    expect(result.shared[0].prefix, '');
    expect(result.shared[0].delimiter, '.');
  });

  test('5.3 personal and one shared namespace', () {
    final result = parse([
      '* NAMESPACE (("" "/")) NIL (("Public Folders/" "/"))',
    ])!;
    expect(result.personal[0].prefix, '');
    expect(result.shared.length, 1);
    expect(result.shared[0].prefix, 'Public Folders/');
    expect(result.shared[0].delimiter, '/');
  });

  test('5.4 other users and several shared namespaces with differing '
      'delimiters', () {
    const line =
        '* NAMESPACE (("" "/")) (("~" "/")) (("#shared/" "/")'
        '("#public/" "/")("#ftp/" "/")("#news." "."))';
    final result = parse([line])!;
    expect(result.personal.length, 1);
    expect(result.otherUsers.length, 1);
    expect(result.otherUsers[0].prefix, '~');
    expect(result.otherUsers[0].delimiter, '/');
    expect(result.shared.length, 4);
    expect(result.shared.map((n) => n.prefix), [
      '#shared/',
      '#public/',
      '#ftp/',
      '#news.',
    ]);
    expect(result.shared.map((n) => n.delimiter), ['/', '/', '/', '.']);
  });

  test('5.5 personal namespace with an INBOX. prefix', () {
    final result = parse(['* NAMESPACE (("INBOX." ".")) NIL  NIL'])!;
    expect(result.personal[0].prefix, 'INBOX.');
    expect(result.personal[0].delimiter, '.');
    expect(result.otherUsers, isEmpty);
    expect(result.shared, isEmpty);
  });

  test('5.6 two personal namespaces, one with a response extension', () {
    const line =
        '* NAMESPACE (("" "/")("#mh/" "/" "X-PARAM" ("FLAG1" '
        '"FLAG2"))) NIL NIL';
    final result = parse([line])!;
    expect(result.personal.length, 2);
    expect(result.personal[0].prefix, '');
    expect(result.personal[0].extensions, isEmpty);
    expect(result.personal[1].prefix, '#mh/');
    expect(result.personal[1].delimiter, '/');
    expect(result.personal[1].extensions, {
      'X-PARAM': ['FLAG1', 'FLAG2'],
    });
  });

  test('5.7 other users namespace', () {
    final result = parse([
      '* NAMESPACE (("" "/")) (("Other Users/" "/")) NIL',
    ])!;
    expect(result.otherUsers[0].prefix, 'Other Users/');
    expect(result.shared, isEmpty);
  });

  test('5.9 prefix without a hierarchy delimiter', () {
    final result = parse(['* NAMESPACE (("" "/")) (("~" "/")) NIL'])!;
    expect(result.otherUsers[0].prefix, '~');
  });

  test('NIL delimiter means no hierarchy', () {
    final result = parse(['* NAMESPACE (("" NIL)) NIL NIL'])!;
    expect(result.personal[0].prefix, '');
    expect(result.personal[0].delimiter, isNull);
  });

  test('quoted specials are unescaped', () {
    final result = parse([r'* NAMESPACE (("Quote\"d\\/" "/")) NIL NIL'])!;
    expect(result.personal[0].prefix, r'Quote"d\/');
  });

  test('a prefix in modified UTF-7 is decoded', () {
    final result = parse([
      '* NAMESPACE (("" "/")) NIL (("Shared&-Mail/" "/"))',
    ])!;
    expect(result.shared[0].encodedPrefix, 'Shared&-Mail/');
    expect(result.shared[0].prefix, 'Shared&Mail/');
  });

  test('a prefix sent as a literal is one token', () {
    final result = parse([
      '* NAMESPACE (("" "/")) NIL (({8}',
      '#shared/',
      ' "/"))',
    ])!;
    expect(result.shared.length, 1);
    expect(result.shared[0].prefix, '#shared/');
    expect(result.shared[0].delimiter, '/');
  });

  test('without the leading star, as the client hands it over', () {
    final result = parse(['NAMESPACE (("" "/")) NIL (("Echoes/" "/"))'])!;
    expect(result.personal[0].prefix, '');
    expect(result.shared[0].prefix, 'Echoes/');
  });

  test('malformed responses are rejected', () {
    expect(parse(['* NAMESPACE (("" "/")) NIL']), isNull, reason: 'two items');
    expect(parse(['* NAMESPACE (()) NIL NIL']), isNull, reason: 'empty pair');
    expect(parse(['* NAMESPACE () NIL NIL']), isNull, reason: 'empty list');
    expect(
      parse(['* NAMESPACE (("" "/") NIL NIL']),
      isNull,
      reason: 'unbalanced',
    );
    expect(
      parse(['* NAMESPACE (("unterminated "/")) NIL NIL']),
      isNull,
      reason: 'unterminated quote',
    );
    expect(
      parse(['* NAMESPACE (("" "/")) NIL NIL trailing']),
      isNull,
      reason: 'trailing data',
    );
    expect(
      parse(['* NAMESPACE (("" "/" "X-PARAM" FLAG1)) NIL NIL']),
      isNull,
      reason: 'extension values not a list',
    );
  });

  test('other untagged lines are not consumed', () {
    final details = ImapResponse()
      ..add(ImapResponseLine('* CAPABILITY IMAP4rev1 NAMESPACE'));
    final parser = NamespaceParser();
    final response = Response<NamespaceResponse?>()..status = ResponseStatus.ok;
    expect(parser.parseUntagged(details, response), false);
    expect(parser.parse(details, response), isNull);
  });

  test('toString renders the wire form', () {
    const line =
        '* NAMESPACE (("" "/")("#mh/" "/" "X-PARAM" ("FLAG1" '
        '"FLAG2"))) NIL (("Echoes/" NIL))';
    final result = parse([line])!;
    expect(
      result.toString(),
      'NAMESPACE (("" "/")("#mh/" "/" "X-PARAM" ("FLAG1" "FLAG2"))) '
      'NIL (("Echoes/" NIL))',
    );
  });
}
