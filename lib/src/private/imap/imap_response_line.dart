import 'dart:convert';
import 'dart:typed_data';

import 'parser_helper.dart';

class ImapResponseLine {
  ImapResponseLine.raw(this.rawData) : rawLine = null;

  ImapResponseLine(final String text)
      : rawData = null,
        rawLine = text {
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
      literal = ParserHelper.parseIntByIndex(text, openIndex + 1, endIndex);
      if (literal != null) {
        if (openIndex > 0 && text[openIndex - 1] == ' ') {
          openIndex--;
        }
        _line = text.substring(0, openIndex);
      }
    }
  }

  static const Utf8Decoder _decoder = Utf8Decoder(allowMalformed: true);
  final String? rawLine;
  String? _line;
  String? get line {
    if (_line == null) {
      final rawData = this.rawData;
      if (rawData != null) {
        _line = _decoder.convert(rawData);
      }
    }
    return _line;
  }

  int? literal;
  bool get isWithLiteral {
    final literal = this.literal;
    return literal != null && literal >= 0;
  }

  final Uint8List? rawData;

  @override
  String toString() {
    return rawLine!;
  }
}
