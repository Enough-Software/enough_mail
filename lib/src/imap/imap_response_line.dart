import 'dart:typed_data';

import 'parser_helper.dart';

class ImapResponseLine {
  String rawLine;
  String line;
  int literal;
  bool get isWithLiteral => (literal != null && literal > 0);
  Uint8List rawData;

  ImapResponseLine.raw(this.rawData)  {
    line = String.fromCharCodes(rawData);
    rawLine = line;
  }

  ImapResponseLine(this.rawLine) {
    // Example for lines using the literal extension / rfc7888:
    //  C: A001 LOGIN {11+}
    //  C: FRED FOOBAR {7+}
    //  C: fat man
    //  S: A001 OK LOGIN completed
    var text = rawLine;
    line = text;
    if (text.length > 3 && text[text.length - 1] == '}') {
      var openIndex = text.lastIndexOf('{', text.length - 2);
      var endIndex = text.length - 1;
      if (text[endIndex -1] == '+') {
        endIndex--;
      }
      literal =
          ParserHelper.parseIntByIndex(text, openIndex + 1, endIndex);
      if (literal != null) {
        if (openIndex > 0 && text[openIndex-1] == ' ') {
          openIndex--;
        }
        line = text.substring(0, openIndex);
      }
    }
  }

  @override
  String toString() {
    return rawLine;
  }
}
