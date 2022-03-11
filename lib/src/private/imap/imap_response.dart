import 'dart:convert';
import 'dart:typed_data';

import '../util/ascii_runes.dart';
import '../util/stack_list.dart';
import 'imap_response_line.dart';

/// Contains an IMAP response in a generic form
class ImapResponse {
  /// The lines in the response
  List<ImapResponseLine> lines = <ImapResponseLine>[];

  /// Is this a simple response ie only containing a single response line?
  bool get isSimple => lines.length == 1;

  /// Retrieves the first line
  ImapResponseLine get first => lines.first;
  String? _parseText;

  /// Retrieves the text of the response ready for parsing
  String get parseText {
    var text = _parseText;
    if (text == null) {
      if (isSimple) {
        text = first.line ?? '';
      } else {
        final buffer = StringBuffer();
        for (final line in lines) {
          buffer.write(line.line);
        }
        text = buffer.toString();
      }
      _parseText = text;
    }
    return text;
  }

  set parseText(String? text) => _parseText = text;
  static const List<String> _knownParenthesesDataItems = [
    'BODY',
    'BODYSTRUCTURE',
    'ENVELOPE',
    'FETCH',
    'FLAGS'
  ];

  /// Adds a line to this response
  void add(ImapResponseLine line) {
    lines.add(line);
  }

  /// Iterates through the value of this response
  ImapValueIterator iterate() {
    final root = ImapValue(null, hasChildren: true);
    var current = root;
    var nextLineIsValueOnly = false;
    final parentheses = StackList<ParenthesizedListType>();

    for (final line in lines) {
      if (nextLineIsValueOnly) {
        final child = ImapValue(null)..data = line.rawData;
        current.addChild(child);
      } else {
        // iterate through each value:
        var isInValue = false;
        int? separatorChar;
        final text = line.line!;
        late int startIndex;
        int? lastChar;
        final textCodeUnits = text.codeUnits;

        var detectedEscapeSequence = false;
        for (var charIndex = 0; charIndex < textCodeUnits.length; charIndex++) {
          final char = textCodeUnits[charIndex];
          if (isInValue) {
            if (char == AsciiRunes.runeOpeningBracket &&
                separatorChar == AsciiRunes.runeSpace) {
              // this can be for example:
              // BODY[]
              // BODY[HEADER]
              // but also:
              // BODY[HEADER.FIELDS (REFERENCES)]
              // BODY[HEADER.FIELDS.NOT (REFERENCES)]
              // --> read on until closing "]"
              separatorChar = AsciiRunes.runeClosingBracket;
            } else if (char == separatorChar) {
              // end of current word:
              if (separatorChar == AsciiRunes.runeClosingBracket) {
                // also include the closing ']' into the value:
                charIndex++;
              } else if (separatorChar == AsciiRunes.runeDoubleQuote &&
                  lastChar == AsciiRunes.runeBackslash) {
                detectedEscapeSequence = true;
                // this can happen e.g. in Subject fields within an ENVELOPE value: "hello \"sir\""
                lastChar = char;
                continue;
              }
              var valueText = text.substring(startIndex, charIndex);
              if (detectedEscapeSequence) {
                valueText = valueText.replaceAll('\\"', '"');
                detectedEscapeSequence = false;
              }
              current.addChild(ImapValue(valueText));
              isInValue = false;
            } else if (parentheses.isNotEmpty &&
                separatorChar == AsciiRunes.runeSpace &&
                char == AsciiRunes.runeClosingParentheses) {
              final valueText = text.substring(startIndex, charIndex);
              current.addChild(ImapValue(valueText));
              isInValue = false;
              parentheses.pop();
              if (current.parent != null) {
                current = current.parent!;
              }
            }
          } else if (char == AsciiRunes.runeDoubleQuote) {
            separatorChar = char;
            startIndex = charIndex + 1;
            isInValue = true;
          } else if (char == AsciiRunes.runeOpeningParentheses) {
            final lastSibling =
                current.hasChildren ? current.children!.last : null;
            ImapValue next;
            if (lastSibling != null &&
                _knownParenthesesDataItems.contains(lastSibling.value)) {
              lastSibling.children ??= <ImapValue>[];
              next = lastSibling;
              parentheses.put(ParenthesizedListType.sibling);
            } else {
              next = ImapValue(null, hasChildren: true);
              current.addChild(next);
              parentheses.put(ParenthesizedListType.child);
            }
            current = next;
          } else if (char == AsciiRunes.runeClosingParentheses) {
            final lastType = parentheses.pop();
            if (current.parent != null) {
              current = current.parent!;
            } else {
              print('Warning: no parent for closing parentheses, '
                  'last parentheses type $lastType');
            }
          } else if (char != AsciiRunes.runeSpace) {
            isInValue = true;
            separatorChar = AsciiRunes.runeSpace;
            startIndex = charIndex;
          }
          lastChar = char;
        } // for each char
        if (isInValue) {
          isInValue = false;
          final valueText = text.substring(startIndex);
          current.addChild(ImapValue(valueText));
        }
      }
      nextLineIsValueOnly = line.isWithLiteral;
    }
    if (parentheses.isNotEmpty) {
      print('Warning - some parentheses have not been closed: $parentheses');
      print(lines.toString());
    }
    return ImapValueIterator(root.children!);
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    for (final line in lines) {
      buffer
        ..write(line.rawLine ?? '<${line.rawData?.length} bytes data>')
        ..write('\n');
    }
    return buffer.toString();
  }
}

/// Iterator through parenthesized values in an IMAP response
class ImapValueIterator {
  /// Creates a new iterator
  ImapValueIterator(this.values);

  /// All values
  final List<ImapValue> values;
  int _currentIndex = 0;

  /// The current value
  ImapValue get current => values[_currentIndex];

  /// Moves to the next value
  ///
  /// Returns `true` if there is a next value
  bool next() {
    if (_currentIndex < values.length - 1) {
      _currentIndex++;
      return true;
    }
    return false;
  }
}

/// The type of a value list element
enum ParenthesizedListType {
  /// A child of another element
  child,

  /// A sibling of another element
  sibling
}

/// Contains a single IMAP value in a parenthesized list
class ImapValue {
  /// Creates a new value
  ImapValue(this.value, {bool hasChildren = false}) {
    if (hasChildren) {
      children = <ImapValue>[];
    }
  }

  /// The parent of this value
  ImapValue? parent;

  /// The text data
  String? value;

  /// The binary data
  Uint8List? data;

  /// The children, if any
  List<ImapValue>? children;

  /// Does this value have children?
  bool get hasChildren => children?.isNotEmpty ?? false;

  /// Retrieves the value as text
  String? get valueOrDataText =>
      value ?? (data == null ? null : utf8.decode(data!, allowMalformed: true));

  /// Adds a child to this value
  void addChild(ImapValue child) {
    children ??= <ImapValue>[];
    child.parent = this;
    children!.add(child);
  }

  @override
  String toString() =>
      (value ?? (data != null ? '<${data!.length} bytes>' : '<null>')) +
      (children != null ? children.toString() : '');
}
