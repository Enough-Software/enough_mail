import 'dart:typed_data';

/// Combines several Uin8Lists to read from them sequentially
class Uint8ListReader {
  Uint8List _data = Uint8List(0);

  void add(Uint8List list) {
    //idea: consider BytesBuilder
    if (_data.isEmpty) {
      _data = list;
    } else {
      _data = Uint8List.fromList(_data + list);
    }
  }

  void addText(String text) {
    add(Uint8List.fromList(text.codeUnits));
  }

  int findLineBreak() {
    var data = _data;
    for (var charIndex = 0; charIndex < data.length - 1; charIndex++) {
      if (data[charIndex] == 13 && data[charIndex + 1] == 10) {
        // ok found CR + LF sequence:
        return charIndex + 1;
      }
    }

    return null;
  }

  int findLastLineBreak() {
    var data = _data;
    for (var charIndex = data.length; --charIndex > 1;) {
      if (data[charIndex] == 10 && data[charIndex - 1] == 13) {
        // ok found CR + LF sequence:
        return charIndex;
      }
    }
    return null;
  }

  bool hasLineBreak() {
    return (findLineBreak() != null);
  }

  String readLine() {
    var pos = findLineBreak();
    if (pos == null) {
      return null;
    }
    var line = String.fromCharCodes(_data, 0, pos - 1);
    _data = _data.sublist(pos + 1);
    return line;
  }

  List<String> readLines() {
    var pos = findLastLineBreak();
    if (pos == null) {
      return null;
    }
    String text;
    if (pos == _data.length - 1) {
      text = String.fromCharCodes(_data);
      _data = Uint8List(0);
    } else {
      text = String.fromCharCodes(_data, 0, pos);
      _data = _data.sublist(pos + 1);
    }
    return text.split('\r\n');
  }

  Uint8List readBytes(int length) {
    if (!isAvailable(length)) {
      return null;
    }
    var result = _data.sublist(0, length);
    _data = _data.sublist(length);
    return result;
  }

  bool isAvailable(int length) {
    return (length <= _data.length);
  }
}
