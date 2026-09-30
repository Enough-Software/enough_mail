import 'dart:convert';
import 'dart:typed_data';

import 'package:collection/collection.dart' show IterableExtension;

import 'codecs/mail_codec.dart';
import 'mime_message.dart';
import 'private/imap/parser_helper.dart';
import 'private/util/ascii_runes.dart';
import 'private/util/byte_utils.dart';

/// Abstracts textual or binary mime data
abstract class MimeData {
  /// Creates a new mime data
  ///
  /// Specify if this data contains header information with [containsHeader].
  MimeData({required this.containsHeader});

  /// Defines if this mime data includes header data
  final bool containsHeader;

  /// All known headers of this mime data
  List<Header>? headersList;

  /// Returns `true` when there are children
  bool get hasParts => parts?.isNotEmpty ?? false;

  /// The children of this mime data
  List<MimeData>? parts;

  ContentTypeHeader? _contentType;

  /// The content type of this mime data
  ContentTypeHeader? get contentType {
    var value = _contentType;
    if (value == null) {
      final headerText = _getHeaderValue('content-type');
      if (headerText != null) {
        value = ContentTypeHeader(headerText);
      }
    }

    return value;
  }

  /// The maximum depth of nested multipart structures that is parsed.
  ///
  /// Deeper nested content is kept as an opaque part. Real messages rarely
  /// exceed a depth of ten, so this only stops maliciously crafted messages
  /// from consuming excessive stack and CPU time.
  static const int maxNestingDepth = 50;

  int _nestingDepth = 0;

  bool _isParsed = false;
  ContentTypeHeader? _parsingContentTypeHeader;

  int _size = 0;

  /// Size of the entire MimePart
  int get size => _size;

  int _bodySize = 0;

  /// Size of the MimePart body
  int get bodySize => _bodySize;

  /// Decodes the text represented by the mime data
  String decodeText(
    ContentTypeHeader? contentTypeHeader,
    String? contentTransferEncoding,
  );

  /// Decodes the data represented by the mime data
  Uint8List decodeBinary(String? contentTransferEncoding);

  /// Decodes message/rfc822 content
  MimeData? decodeMessageData();

  /// Parses this data
  void parse(ContentTypeHeader? contentTypeHeader) {
    if (_isParsed && (contentTypeHeader == _parsingContentTypeHeader)) {
      return;
    }
    _isParsed = true;
    _parsingContentTypeHeader = contentTypeHeader;
    _parseContent(contentTypeHeader);
  }

  void _parseContent(ContentTypeHeader? contentTypeHeader);

  /// Renders this mime data.
  ///
  /// Optionally set [renderHeader] to `false` in case the
  /// message header should be skipped.
  void render(StringBuffer buffer, {bool renderHeader = true});

  Header? _getHeader(String lowerCaseName) =>
      headersList?.firstWhereOrNull((h) => h.lowerCaseName == lowerCaseName);

  String? _getHeaderValue(String lowerCaseName) =>
      _getHeader(lowerCaseName)?.value;

  @override
  String toString() {
    final buffer = StringBuffer();
    render(buffer);

    return buffer.toString();
  }
}

/// Represents textual mime data
class TextMimeData extends MimeData {
  /// Creates a new text based mime data
  ///
  /// with the specified [text] and the [containsHeader] information.
  ///
  /// Line endings are automatically normalized to CRLF (`\r\n`) for
  /// RFC 5322 compliance, tolerating bare LF from non-conformant MIME
  /// generators (e.g. Node.js mimetext on Linux which uses `os.EOL`).
  TextMimeData(String text, {required bool containsHeader})
    : text = _normalizeLineEndings(text),
      super(containsHeader: containsHeader) {
    _size = this.text.length;
  }

  /// Creates a child part from already normalized [text] at [depth].
  TextMimeData._child(this.text, int depth) : super(containsHeader: true) {
    _size = text.length;
    _nestingDepth = depth;
  }

  /// Normalizes bare LF to CRLF for RFC 5322 compliance.
  static String _normalizeLineEndings(String text) =>
      text.replaceAll(RegExp(r'(?<!\r)\n'), '\r\n');

  /// Splits a multipart [body] at its [boundary] delimiters.
  ///
  /// As required by RFC 2046 section 5.1.1 a delimiter is only recognized at
  /// the start of a line (or at the very start of the body), so that text
  /// merely containing `--boundary` cannot introduce a part. The CRLF that
  /// precedes a delimiter is kept as part of the preceding part's content.
  static List<String> splitMultipart(String body, String boundary) {
    final delimiter = RegExp(
      '(?:^|\\r\\n)--${RegExp.escape(boundary)}(--)?[ \\t]*(?:\\r\\n|\$)',
    );
    final parts = <String>[];
    int? partStart;
    for (final match in delimiter.allMatches(body)) {
      if (partStart != null) {
        final partEnd = body.startsWith('\r\n', match.start)
            ? match.start + 2
            : match.start;
        parts.add(body.substring(partStart, partEnd));
      }
      if (match.group(1) != null) {
        // closing delimiter, anything after it is the epilogue
        return parts;
      }
      partStart = match.end;
    }
    if (partStart != null) {
      // no closing delimiter: the remainder is the last part
      parts.add(body.substring(partStart));
    }

    return parts;
  }

  /// The text representation of the full mime data
  final String text;

  /// The body of the data
  late String body;

  @override
  void _parseContent(ContentTypeHeader? contentTypeHeader) {
    var bodyText = text;
    if (containsHeader) {
      if (text.startsWith('\r\n')) {
        // this part has no header
        bodyText = text.substring(2);
      } else {
        final headerParseResult = ParserHelper.parseHeader(text);
        final bodyStartIndex = headerParseResult.bodyStartIndex;
        if (bodyStartIndex != null) {
          bodyText = bodyStartIndex >= text.length
              ? ''
              : text.substring(bodyStartIndex);
        }
        headersList = headerParseResult.headersList;
      }
      // ignore: parameter_assignments
      contentTypeHeader ??= contentType;
    } else {
      bodyText = text;
    }
    body = bodyText;
    _bodySize = body.length;
    if (_nestingDepth >= MimeData.maxNestingDepth) {
      return;
    }
    String? partsBoundary;
    if (contentTypeHeader?.mediaType.isMessage ?? false) {
      final headStop = body.indexOf('\r\n\r\n');
      final head = headStop == -1 ? body : body.substring(0, headStop);
      partsBoundary = RegExp(r'boundary="([^"]+)"').firstMatch(head)?.group(1);
    } else {
      partsBoundary = contentTypeHeader?.boundary;
    }
    if (partsBoundary != null) {
      parts = [];
      for (final childPart in splitMultipart(bodyText, partsBoundary)) {
        if (childPart.isNotEmpty) {
          final part = TextMimeData._child(childPart, _nestingDepth + 1)
            ..parse(null);
          parts?.add(part);
        }
      }
    }
  }

  @override
  void render(StringBuffer buffer, {bool renderHeader = true}) {
    if (!renderHeader && containsHeader) {
      buffer.write(body);
    } else {
      buffer.write(text);
    }
  }

  @override
  Uint8List decodeBinary(String? contentTransferEncoding) =>
      MailCodec.decodeBinary(body, contentTransferEncoding);

  @override
  String decodeText(
    ContentTypeHeader? contentTypeHeader,
    String? contentTransferEncoding,
  ) => MailCodec.decodeAnyText(
    body,
    contentTransferEncoding,
    contentTypeHeader?.charset,
  );

  @override
  MimeData? decodeMessageData() => TextMimeData(body, containsHeader: true);
}

/// Represents binary mime data
class BinaryMimeData extends MimeData {
  /// Creates a new binary mime data
  ///
  /// with the specified [data] and the [containsHeader] info.
  BinaryMimeData(this.data, {required bool containsHeader})
    : super(containsHeader: containsHeader) {
    _size = data.length;
  }

  BinaryMimeData._child(this.data, int depth) : super(containsHeader: true) {
    _size = data.length;
    _nestingDepth = depth;
  }

  /// The binary data
  final Uint8List data;
  int? _bodyStartIndex;
  late Uint8List _bodyData;

  @override
  void _parseContent(ContentTypeHeader? contentTypeHeader) {
    if (containsHeader) {
      headersList = _parseHeader();
    } else {
      _bodyStartIndex = 0;
    }
    final bodyStartIndex = _bodyStartIndex;
    if (bodyStartIndex == null) {
      _bodyData = Uint8List(0);
    } else {
      _bodyData = bodyStartIndex == 0 ? data : data.sublist(bodyStartIndex);
      final usedContentType = contentTypeHeader ?? contentType;
      String? partsBoundary;
      if (usedContentType?.mediaType.isMessage ?? false) {
        final headStop = '\r\n\r\n'.codeUnits;
        final headStopIndex = ByteUtils.findSequence(_bodyData, headStop);
        if (headStopIndex > 0) {
          final matcher = 'boundary="'.codeUnits;
          final boundaryPos = ByteUtils.findSequence(
            Uint8List.sublistView(_bodyData, 0, headStopIndex),
            matcher,
          );
          if (boundaryPos > 0) {
            final valueStart = boundaryPos + matcher.length;
            // the closing quote must be within the header section
            final valueEnd = _bodyData.indexOf(
              AsciiRunes.runeDoubleQuote,
              valueStart,
            );
            if (valueEnd > valueStart && valueEnd < headStopIndex) {
              partsBoundary = String.fromCharCodes(
                _bodyData.sublist(valueStart, valueEnd),
              );
            }
          }
        }
      } else {
        // Generic multipart
        partsBoundary = usedContentType?.boundary;
      }
      if (partsBoundary != null && _nestingDepth < MimeData.maxNestingDepth) {
        // split into different parts:
        parts = _splitAndParse(partsBoundary, _bodyData);
      }
    }
    _bodySize = _bodyData.length;
  }

  static bool _matchesAt(Uint8List data, int index, List<int> sequence) {
    if (index + sequence.length > data.length) {
      return false;
    }
    for (var j = 0; j < sequence.length; j++) {
      if (data[index + j] != sequence[j]) {
        return false;
      }
    }

    return true;
  }

  /// Splits [bodyData] at its multipart delimiters, compare
  /// [TextMimeData.splitMultipart] for the rules that are applied.
  List<BinaryMimeData> _splitAndParse(
    final String boundaryText,
    final Uint8List bodyData,
  ) {
    final delimiter = '--$boundaryText'.codeUnits;
    final result = <BinaryMimeData>[];
    final length = bodyData.length;
    int? partStart;
    var i = 0;
    while (i + delimiter.length <= length) {
      final isLineStart =
          i == 0 ||
          (i >= 2 &&
              bodyData[i - 1] == AsciiRunes.runeLineFeed &&
              bodyData[i - 2] == AsciiRunes.runeCarriageReturn);
      if (!isLineStart || !_matchesAt(bodyData, i, delimiter)) {
        i++;
        continue;
      }
      var end = i + delimiter.length;
      final isClosing =
          end + 1 < length &&
          bodyData[end] == AsciiRunes.runeMinus &&
          bodyData[end + 1] == AsciiRunes.runeMinus;
      if (isClosing) {
        end += 2;
      }
      // skip transport padding:
      while (end < length &&
          (bodyData[end] == AsciiRunes.runeSpace ||
              bodyData[end] == AsciiRunes.runeTab)) {
        end++;
      }
      if (end < length) {
        if (end + 1 < length &&
            bodyData[end] == AsciiRunes.runeCarriageReturn &&
            bodyData[end + 1] == AsciiRunes.runeLineFeed) {
          end += 2;
        } else if (!isClosing) {
          // this is a different, longer boundary and not a delimiter
          i++;
          continue;
        }
      }
      if (partStart != null) {
        result.add(
          BinaryMimeData._child(
            bodyData.sublist(partStart, i),
            _nestingDepth + 1,
          )..parse(null),
        );
      }
      if (isClosing) {
        return result;
      }
      partStart = end;
      i = end;
    }
    if (partStart != null && partStart < length) {
      // no closing delimiter: the remainder is the last part
      result.add(
        BinaryMimeData._child(bodyData.sublist(partStart), _nestingDepth + 1)
          ..parse(null),
      );
    }

    return result;
  }

  @override
  String decodeText(
    ContentTypeHeader? contentTypeHeader,
    String? contentTransferEncoding,
  ) => _bodyStartIndex == null
      ? ''
      : MailCodec.decodeAsText(
          _bodyData,
          contentTransferEncoding,
          contentTypeHeader?.charset,
        );

  @override
  Uint8List decodeBinary(String? contentTransferEncoding) {
    final contentTransferEncodingLC = contentTransferEncoding?.toLowerCase();
    if (_bodyStartIndex == null ||
        // do not try to decode textual content:
        contentTransferEncodingLC == '7bit' ||
        contentTransferEncodingLC == '8bit' ||
        contentTransferEncodingLC == 'quoted-printable') {
      return _bodyData;
    }
    // even with a 'binary' content transfer encoding there are \r\n
    // characters that need to be handled,
    // so translate to text first
    final dataText = utf8.decode(_bodyData);

    return MailCodec.decodeBinary(dataText, contentTransferEncodingLC);
  }

  List<Header> _parseHeader() {
    final headerData = data;
    // shortcut for having an empty line at the start:
    if (headerData.length > 1 &&
        headerData[0] == AsciiRunes.runeCarriageReturn &&
        headerData[1] == AsciiRunes.runeLineFeed) {
      _bodyStartIndex = 2;

      return [];
    }
    // check for first CRLF-CRLF sequence:
    for (var i = 0; i < headerData.length - 4; i++) {
      if (headerData[i] == AsciiRunes.runeCarriageReturn &&
          headerData[i + 1] == AsciiRunes.runeLineFeed &&
          headerData[i + 2] == AsciiRunes.runeCarriageReturn &&
          headerData[i + 3] == AsciiRunes.runeLineFeed) {
        final headerLines = String.fromCharCodes(
          headerData,
          0,
          i,
        ).split('\r\n');
        _bodyStartIndex = i + 4;

        return ParserHelper.parseHeaderLines(headerLines).headersList;
      }
    }
    // the whole data is just headers:
    final headerLines = String.fromCharCodes(headerData).split('\r\n');

    return ParserHelper.parseHeaderLines(headerLines).headersList;
  }

  @override
  void render(StringBuffer buffer, {bool renderHeader = true}) {
    if (!renderHeader && containsHeader) {
      final text = String.fromCharCodes(_bodyData);
      buffer.write(text);
    } else {
      final text = String.fromCharCodes(data);
      buffer.write(text);
    }
  }

  @override
  MimeData? decodeMessageData() =>
      BinaryMimeData(_bodyData, containsHeader: true);
}
