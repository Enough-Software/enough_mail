import '../../codecs/mail_codec.dart';
import '../../mime_message.dart';
import '../util/ascii_runes.dart';
import '../util/word.dart';

/// Abstracts a word such as a template name
class ParserHelper {
  ParserHelper._();

  /// Helper method for parsing integer values within a line [details].
  static int? parseInt(String details, int startIndex, String endCharacter) {
    final endIndex = details.indexOf(endCharacter, startIndex);
    if (endIndex == -1) {
      return -1;
    }
    final numericText = details.substring(startIndex, endIndex);
    return int.tryParse(numericText);
  }

  /// Helper method for parsing integer values within a line [details].
  static int? parseIntByIndex(String details, int startIndex, int endIndex) {
    final numericText = details.substring(startIndex, endIndex);
    return int.tryParse(numericText);
  }

  /// Helper method to parse list entries in a line [details].
  static List<String>? parseListEntries(
      String details, int startIndex, String? endCharacter,
      [String separator = ' ']) {
    final runes = details.runes.toList();
    final separatorRune = separator.runes.first;
    final endRune = endCharacter?.runes.first;
    final result = <String>[];
    var isInQuote = false;
    var isLastEscaped = false;
    var entryStartIndex = startIndex;
    for (var i = startIndex; i < runes.length; i++) {
      final rune = runes[i];
      if (isLastEscaped) {
        isLastEscaped = false;
      } else if (rune == AsciiRunes.runeDoubleQuote) {
        isInQuote = !isInQuote;
      } else if (rune == AsciiRunes.runeBackslash) {
        isLastEscaped = true;
      } else if (!isInQuote) {
        if (rune == separatorRune || rune == endRune) {
          result.add(details.substring(entryStartIndex, i));
          entryStartIndex = i + 1;
        }
        if (rune == endRune) {
          return result;
        }
      }
    }
    if (endCharacter != null) {
      return null;
    } else if (entryStartIndex < runes.length) {
      result.add(details.substring(entryStartIndex));
    }

    return result;
  }

  /// Helper method to parse list entries in a line [details].
  static List<String>? parseListEntriesByIndex(
      String details, int startIndex, int endIndex,
      [String separator = ' ']) {
    if (endIndex == -1) {
      return null;
    }
    return details.substring(startIndex, endIndex).split(separator);
  }

  /// Helper method to parse a list of integer values in a line [details].
  static List<int>? parseListIntEntries(
      String details, int startIndex, String endCharacter,
      [String separator = ' ']) {
    final texts =
        parseListEntries(details, startIndex, endCharacter, separator);
    if (texts == null) {
      return null;
    }
    final integers = <int>[];
    for (final text in texts) {
      final number = int.tryParse(text.trim());
      if (number == null) {
        print('Warning: unable to parse entry $text in "$details"');
      } else {
        integers.add(number);
      }
    }
    return integers;
  }

  /// Helper method to read the next word within a string
  static Word? readNextWord(String details, final int startIndex,
      [String separator = ' ']) {
    var endIndex = details.indexOf(separator, startIndex);
    var i = startIndex;
    while (endIndex == i) {
      i++;
      endIndex = details.indexOf(separator, i);
    }
    if (endIndex == -1) {
      return null;
    }
    return Word(details.substring(i, endIndex), i);
  }

  /// Parses the headers from the given [headerText]
  static HeaderParseResult parseHeader(final String headerText) {
    final headerLines = headerText.split('\r\n');
    return parseHeaderLines(headerLines);
  }

  /// Parses the headers from the given [headerLines]
  static HeaderParseResult parseHeaderLines(List<String> headerLines,
      {int startRow = 0}) {
    final result = HeaderParseResult();
    var bodyStartIndex = 0;
    var buffer = StringBuffer();
    String? lastLine;
    for (var i = startRow; i < headerLines.length; i++) {
      final line = headerLines[i];
      if (line.isEmpty) {
        // end of header is marked with an empty line
        if (buffer.isNotEmpty) {
          _addHeader(result, buffer);
          buffer = StringBuffer();
        }
        bodyStartIndex += 2;
        result.bodyStartIndex = bodyStartIndex;
        break;
      }
      bodyStartIndex += line.length + 2;
      if (line.startsWith(' ') || (line.startsWith('\t'))) {
        final trimmed = line.trimLeft();
        if (lastLine == null ||
            !lastLine.endsWith('=') ||
            !trimmed.startsWith('=')) {
          buffer.write(' ');
        }
        buffer.write(trimmed);
      } else {
        if (buffer.isNotEmpty) {
          // got a complete line
          _addHeader(result, buffer);
          buffer = StringBuffer();
        }
        buffer.write(line);
      }
      lastLine = line;
    }
    if (buffer.isNotEmpty) {
      // got a complete line
      _addHeader(result, buffer);
    }
    return result;
  }

  static void _addHeader(HeaderParseResult result, StringBuffer buffer) {
    final headerText = buffer.toString();
    final colonIndex = headerText.indexOf(':');
    if (colonIndex != -1) {
      final name = headerText.substring(0, colonIndex);
      if (colonIndex + 2 < headerText.length) {
        final value = headerText.substring(colonIndex + 1).trim();
        result.add(name, value);
      } else {
        //print('encountered empty header [$headerText]');
        result.add(name, '');
      }
    }
  }

  /// Parses an email from the given [value] text
  /// like `"name" <address@domain.com>`
  static String? parseEmail(String value) {
    if (value.length < 3) {
      return null;
    }
    // check for a value like '"name" <address@domain.com>'
    final startIndex = value.indexOf('<');
    if (startIndex != -1) {
      final endIndex = value.indexOf('>');
      if (endIndex > startIndex + 1) {
        return value.substring(startIndex + 1, endIndex - 1);
      }
    }
    // maybe this is just '"name" address@domain.com'?
    if (value.startsWith('"')) {
      final endIndex = value.indexOf('"', 1);
      if (endIndex != -1) {
        return value.substring(endIndex + 1).trim();
      }
    }
    return value;
  }
}

/// Contains the result for a parsed header
class HeaderParseResult {
  /// The parsed headers
  final headersList = <Header>[];

  /// The position of the body
  int? bodyStartIndex;

  /// Adds a header with the given [name] and [value]
  void add(String name, String value) {
    final header = Header(name, value, MailCodec.detectHeaderEncoding(value));
    headersList.add(header);
  }
}
