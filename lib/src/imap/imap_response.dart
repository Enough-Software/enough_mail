import 'package:enough_mail/util/stack_list.dart';

import 'imap_response_line.dart';


class ImapResponse {
  List<ImapResponseLine> lines = <ImapResponseLine>[];
  bool get isSimple => (lines.length == 1);
  ImapResponseLine get first => lines.first;
  String _parseText;
  String get parseText => _getParseText();
  set parseText(String text) => _parseText = text;

  void add(ImapResponseLine line) {
    lines.add(line);
  }

  String _getParseText() {
    if (_parseText == null) {
      if (isSimple) {
        _parseText = first.line;
      } else {
        var buffer = StringBuffer();
        for (var line in lines) {
          buffer.write(line.line);
        }
        _parseText = buffer.toString();
      }
    }
    return _parseText;
  }

  ImapValueIterator iterate() {
    var root = ImapValue(null, true);
    var current = root;
    var nextLineIsValueOnly = false;
    var parentheses = StackList<ImapValueParenthesis>();

    for (var line in lines) {
      if (nextLineIsValueOnly) {
        current.addChild(ImapValue(line.line));
      } else {
        // iterate through each value:
        var isInValue = false;
        String separatorChar;
        var text = line.line;
        int startIndex;
        for (var charIndex = 0; charIndex < text.length; charIndex++) {
          var char = text[charIndex];
          if (isInValue) {
            if (char == '[' && separatorChar == ' ') {            
              // this can be for example:
              // BODY[]
              // BODY[HEADER]
              // but also:
              // BODY[HEADER.FIELDS (REFERENCES)]
              // BODY[HEADER.FIELDS.NOT (REFERENCES)]
              // --> read on until closing "]"
              separatorChar = ']';
            } else if (char == separatorChar) {
              // end of current word:
              if (separatorChar == ']') {
                // also include the closing ']' into the value:
                charIndex++;
              }
              var valueText = text.substring(startIndex, charIndex);
              current.addChild(ImapValue(valueText));
              isInValue = false;
            } else if (parentheses.isNotEmpty &&
                separatorChar == ' ' &&
                char == ')') {
              var valueText = text.substring(startIndex, charIndex);
              current.addChild(ImapValue(valueText));
              isInValue = false;
              charIndex =
                  _closeParentheses(charIndex, text, parentheses, current);
              current = current.parent;
            }
          } else if (char == '"') {
            separatorChar = char;
            startIndex = charIndex + 1;
            isInValue = true;
          } else if (char == '(') {
            // typically subvalues do start here, e.g.
            // 123 FETCH (FLAGS () ...)
            // Another notation is the double-opener, e.g.
            // (("=?UTF-8?Q?Sch=C3=B6n=2C_Rob?=" NIL "rob.schoen" "domain.com"))
            if (charIndex < text.length - 1 && text[charIndex + 1] == '(') {
              // ok, this is a double opener:
              parentheses.put(ImapValueParenthesis.double);
              charIndex++;
              var next = ImapValue(null, true);
              current.addChild(next);
              current = next;
            } else {
              // this is a normal opening list, typically this belongs to the current item
              parentheses.put(ImapValueParenthesis.simple);
              if (current.children == null || current.children.isEmpty) {
                current.addChild(ImapValue(null, true));
              }
              var next = current.children.last;
              if (next.children == null) {
                next.children = <ImapValue>[];
              } else {
                next = ImapValue(null, true);
                current.addChild(next);
              }
              current = next;
            }
          } else if (char == ')') {
            charIndex =
                _closeParentheses(charIndex, text, parentheses, current);
            current = current.parent;
          } else if (char != ' ') {
            isInValue = true;
            separatorChar = ' ';
            startIndex = charIndex;
          }
        }
        if (isInValue) {
          isInValue = false;
          var valueText = text.substring(startIndex);
          current.addChild(ImapValue(valueText));
        }
      }
      nextLineIsValueOnly = line.isWithLiteral;
    }
    if (parentheses.isNotEmpty) {
      print('Warning - some parentheses have not been closed: $parentheses');
      print(lines.toString());
    }
    return ImapValueIterator(root.children);
  }

  int _closeParentheses(int charIndex, String text,
      StackList<ImapValueParenthesis> parentheses, ImapValue current) {
    if (parentheses.peek() == ImapValueParenthesis.double) {
      if (charIndex < text.length - 1 && text[charIndex + 1] == ')') {
        charIndex++;
      } else {
        // edge case: previously two opening parentheses were wrongly interpreted as a double parentheses
        // now move the current list underneath the last value, if possible:
        var siblings = current.parent.children;
        if (siblings.length > 1 &&
            siblings[siblings.length - 2].children == null) {
          siblings[siblings.length - 2].addChild(current);
          siblings.removeLast();
          parentheses.pop();
          parentheses.put(ImapValueParenthesis.simple); 
          parentheses.put(ImapValueParenthesis.simple); // this one is going to be popped next anyhow
        }
      }
    }
    parentheses.pop();
    return charIndex;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    for (var line in lines) {
      buffer.write(line.rawLine);
      buffer.write('\n');
    }
    return buffer.toString();
  }
}

class ImapValueIterator {
  final List<ImapValue> values;
  int _currentIndex = 0;
  ImapValue get current => values[_currentIndex];

  ImapValueIterator(this.values);

  bool next() {
    if (_currentIndex < values.length - 1) {
      _currentIndex++;
      return true;
    }
    return false;
  }
}

enum ImapValueParenthesis { simple, double }

class ImapValue {
  ImapValue parent;
  String value;
  List<ImapValue> children;
  ImapValue(this.value, [bool hasChildren = false]) {
    if (hasChildren) {
      children = <ImapValue>[];
    }
  }

  void addChild(ImapValue child) {
    children ??= <ImapValue>[];
    child.parent = this;
    children.add(child);
  }

  @override
  String toString() {
    return (value == null ? '<null>' : value) +
        (children != null ? children.toString() : '');
  }
}
