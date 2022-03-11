import 'dart:convert';
import 'dart:typed_data';

import 'ascii_runes.dart';

/// Combines several Uin8Lists to read from them sequentially
class Uint8ListReader {
  static const Utf8Decoder _utf8decoder = Utf8Decoder(allowMalformed: true);
  final OptimizedBytesBuilder _builder = OptimizedBytesBuilder();

  /// Adds the given [list] data to this builder
  void add(Uint8List list) => _builder.add(list);

  /// Adds the given [text] to this builder
  void addText(String text) => _builder.add(Uint8List.fromList(text.codeUnits));

  /// Finds the position of the first line break
  int? findLineBreak() => _builder.findLineBreak();

  /// Finds the position of the last line break
  int? findLastLineBreak() => _builder.findLastLineBreak();

  /// Checks of there is a line break
  bool hasLineBreak() => _builder.findLastLineBreak() != null;

  /// Reads the current line until the first line-break
  String? readLine() {
    final pos = _builder.findLineBreak();
    if (pos == null) {
      return null;
    }
    final data = _builder.takeFirst(pos + 1);
    final line = _utf8decoder.convert(data, 0, pos - 1);
    return line;
  }

  /// Reads the lines until the last line break
  List<String>? readLines() {
    final pos = _builder.findLastLineBreak();
    if (pos == null) {
      return null;
    }
    final data = _builder.takeFirst(pos + 1);
    final text = _utf8decoder.convert(data);
    return text.split('\r\n')..removeLast();
  }

  /// Finds the last CR-LF.CR-LF sequence
  int? findLastCrLfDotCrLfSequence() {
    for (var charIndex = _builder.length; --charIndex > 4;) {
      if (_builder.getByteAt(charIndex) == 10 &&
          _builder.getByteAt(charIndex - 1) == 13 &&
          _builder.getByteAt(charIndex - 2) == AsciiRunes.runeDot &&
          _builder.getByteAt(charIndex - 3) == 10 &&
          _builder.getByteAt(charIndex - 4) == 13) {
        // ok found CRLF.CRLF sequence:
        return charIndex;
      }
    }
    return null;
  }

  /// Reads all data until a CT-LF.CT-LF
  List<String>? readLinesToCrLfDotCrLfSequence() {
    final pos = findLastCrLfDotCrLfSequence();
    if (pos == null) {
      return null;
    }
    final data = _builder.takeFirst(pos);
    final text = _utf8decoder.convert(data, 0, pos - 4);
    return text.split('\r\n');
  }

  /// Reads the data until the given [length]
  Uint8List? readBytes(int length) {
    if (!isAvailable(length)) {
      return null;
    }
    return _builder.takeFirst(length);
  }

  /// Checks if the given [length] of data is available
  bool isAvailable(int length) => length <= _builder.length;
}

/// A non-copying [BytesBuilder].
///
/// Accumulates lists of integers and lazily builds
/// a collected list with all the bytes when requested.
class OptimizedBytesBuilder {
  static final _emptyList = Uint8List(0);
  int _length = 0;
  final List<Uint8List> _chunks = [];

  /// Adds the given [bytes] data
  void add(final Uint8List bytes) {
    _chunks.add(bytes);
    _length += bytes.length;
  }

  /// Adds a single [byte] data
  void addByte(int byte) {
    _chunks.add(Uint8List(1)..[0] = byte);
    _length++;
  }

  /// Removes the available bytes
  Uint8List takeBytes() {
    if (_length == 0) {
      return _emptyList;
    }
    if (_chunks.length == 1) {
      final buffer = _chunks[0];
      clear();
      return buffer;
    }
    final buffer = Uint8List(_length);
    var offset = 0;
    for (final chunk in _chunks) {
      buffer.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    clear();
    return buffer;
  }

  /// Takes the first [len] bytes
  Uint8List takeFirst(final int len) {
    if (len <= 0) {
      return _emptyList;
    }
    if (len >= _length) {
      return takeBytes();
    }
    // optimization for first chunk:
    final firstChunk = _chunks.first;
    if (firstChunk.length == len) {
      _chunks.removeAt(0);
      _length -= len;
      return firstChunk;
    }
    final buffer = Uint8List(len);
    var offset = 0;
    var chunkIndex = 0;
    for (final chunk in _chunks) {
      final endOffset = offset + chunk.length;
      if (endOffset > len) {
        // only part of this chunk should be copied:
        buffer.setRange(offset, len, chunk);
        final chunkStartIndex = chunk.length - (endOffset - len);
        final updatedChunk = chunk.sublist(chunkStartIndex);
        _chunks[chunkIndex] = updatedChunk;
        break;
      } else {
        buffer.setRange(offset, endOffset, chunk);
        offset += chunk.length;
      }
      chunkIndex++;
      if (offset >= len) {
        break;
      }
    }
    _chunks.removeRange(0, chunkIndex);
    _length -= len;
    return buffer;
  }

  /// Converts the whole data
  Uint8List toBytes() {
    if (_length == 0) {
      return _emptyList;
    }
    final buffer = Uint8List(_length);
    var offset = 0;
    for (final chunk in _chunks) {
      buffer.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return buffer;
  }

  /// Retrieves the available length
  int get length => _length;

  /// Checks if this builder is empty
  bool get isEmpty => _length == 0;

  /// Checks if this builder is not empty
  bool get isNotEmpty => _length != 0;

  /// Clears the buffer of this builder
  void clear() {
    _length = 0;
    _chunks.clear();
  }

  /// Gets the byte at the given [index]
  int getByteAt(final int index) {
    var i = index;
    for (final chunk in _chunks) {
      if (i < chunk.length) {
        return chunk[i];
      }
      i -= chunk.length;
    }
    throw IndexError(index, this, 'unknown',
        'for index $index in builder with length $length', _length);
  }

  /// Tries to the find the position of the first CR-LF line break
  int? findLineBreak() {
    if (_length == 0) {
      return null;
    }
    var index = 0;
    var isPreviousCr = false;
    for (final chunk in _chunks) {
      for (var charIndex = 0; charIndex < chunk.length - 1; charIndex++) {
        final currentChar = chunk[charIndex];
        if (currentChar == 13 && chunk[charIndex + 1] == 10) {
          // ok found CR + LF sequence:
          return index + 1;
        } else if (isPreviousCr) {
          if (currentChar == 10) {
            return index;
          }
          isPreviousCr = false;
        }
        index++;
      }
      if (isPreviousCr && chunk.length == 1 && chunk[0] == 10) {
        return index;
      }
      isPreviousCr = chunk[chunk.length - 1] == 13;
      index++;
    }
    return null;
  }

  /// Tries to the find the position of the last  CR-LF line break
  int? findLastLineBreak() {
    if (_length == 0) {
      return null;
    }
    var isPreviousLf = false;
    var index = _length;
    for (var chunkIndex = _chunks.length; --chunkIndex >= 0;) {
      final chunk = _chunks[chunkIndex];
      for (var charIndex = chunk.length; --charIndex > 0;) {
        index--;
        final currentChar = chunk[charIndex];
        if (currentChar == 10 && chunk[charIndex - 1] == 13) {
          // ok found CR + LF sequence:
          return index;
        } else if (isPreviousLf) {
          if (currentChar == 13) {
            return index + 1;
          }
          isPreviousLf = false;
        }
      }
      if (isPreviousLf && chunk.length == 1 && chunk[0] == 13) {
        return index - 1;
      }
      isPreviousLf = chunk[0] == 10;
    }
    return null;
  }
}
