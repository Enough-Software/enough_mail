import 'dart:convert';
import 'dart:typed_data';

/// Contains an IMAP response line
class ImapResponseLine {
  /// Creates a textual response line
  ImapResponseLine(final String text) : rawData = null, rawLine = text {
    // Example for lines using the literal extension / rfc7888:
    //  C: A001 LOGIN {11+}
    //  C: FRED FOOBAR {7+}
    //  C: fat man
    //  S: A001 OK LOGIN completed
    //var text = rawLine!;
    _line = text;
    if (text.length > 3 && text[text.length - 1] == '}') {
      var openIndex = text.lastIndexOf('{', text.length - 2);
      var endIndex = text.length - 1;
      if (text[endIndex - 1] == '+') {
        endIndex--;
      }
      if (openIndex != -1) {
        // RFC 3501: literal = "{" number "}" CRLF, number is digits only
        final size = _parseLiteralSize(text, openIndex + 1, endIndex);
        if (size != null) {
          literal = size;
          if (openIndex > 0 && text[openIndex - 1] == ' ') {
            openIndex--;
          }
          _line = text.substring(0, openIndex);
        }
      }
    }
  }

  /// Creates a binary response line
  ImapResponseLine.raw(this.rawData) : rawLine = null;

  static int? _parseLiteralSize(String text, int startIndex, int endIndex) {
    if (endIndex <= startIndex) {
      return null;
    }
    for (var i = startIndex; i < endIndex; i++) {
      final code = text.codeUnitAt(i);
      if (code < 48 || code > 57) {
        return null;
      }
    }

    return int.tryParse(text.substring(startIndex, endIndex));
  }

  static const Utf8Decoder _decoder = Utf8Decoder(allowMalformed: true);

  /// The original text line
  final String? rawLine;
  String? _line;

  /// The processed text line
  String? get line {
    if (_line == null) {
      final rawData = this.rawData;
      if (rawData != null) {
        _line = _decoder.convert(rawData);
      }
    }

    return _line;
  }

  /// The literal at the end of this line.
  ///
  /// Compare [isWithLiteral].
  int? literal;

  /// Does this line have a [literal] data indicator?
  bool get isWithLiteral {
    final literal = this.literal;

    return literal != null && literal >= 0;
  }

  /// The raw data of this line
  final Uint8List? rawData;

  @override
  String toString() => rawLine ?? line ?? '<no valid data>';
}
