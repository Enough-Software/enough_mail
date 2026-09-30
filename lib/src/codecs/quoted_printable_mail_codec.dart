import 'dart:convert';
import 'dart:typed_data';

import '../mail_conventions.dart';
import '../private/util/ascii_runes.dart';
import 'mail_codec.dart';

/// Provides quoted printable encoder and decoder.
///
/// Compare https://tools.ietf.org/html/rfc2045#page-19 for details.
class QuotedPrintableMailCodec extends MailCodec {
  /// Creates a new quoted printable codec
  const QuotedPrintableMailCodec();

  /// Encodes the specified text in quoted printable format.
  ///
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set [wrap] to false in case you do not want to wrap lines.
  @override
  String encodeText(
    final String text, {
    Codec codec = MailCodec.encodingUtf8,
    bool wrap = true,
  }) {
    final buffer = StringBuffer();
    final runes = List.from(text.runes);
    final runeCount = runes.length;

    var lineCharacterCount = 0;

    for (var i = 0; i < runeCount; i++) {
      final rune = runes[i];
      if ((rune >= 32 && rune <= 60) ||
          (rune >= 62 && rune <= 126) ||
          rune == 9) {
        buffer.writeCharCode(rune);
        lineCharacterCount++;
      } else {
        if (i < runeCount - 1 &&
            rune == AsciiRunes.runeCarriageReturn &&
            runes[i + 1] == AsciiRunes.runeLineFeed) {
          buffer.write('\r\n');
          i++;
          lineCharacterCount = 0;
        } else if (rune == AsciiRunes.runeLineFeed) {
          buffer.write('\r\n');
          lineCharacterCount = 0;
        } else {
          //TODO some characters consist of more than a single rune
          lineCharacterCount += _writeQuotedPrintable(rune, buffer, codec);
        }
      }
      if (wrap && lineCharacterCount >= MailConventions.textLineMaxLength - 1) {
        buffer.write('=\r\n'); // soft line break
        lineCharacterCount = 0;
      }
    }

    return buffer.toString();
  }

  /// Encodes the header text in Q encoding only if required.
  ///
  /// Compare https://tools.ietf.org/html/rfc2047#section-4.2 for details.
  /// [text] specifies the text to be encoded.
  /// [nameLength] the length of the header name, for calculating the wrapping
  ///  point.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set the optional [fromStart] to true in case the encoding should  start
  /// at the beginning of the text and not in the middle.
  @override
  String encodeHeader(
    final String text, {
    int nameLength = 0,
    Codec codec = utf8,
    bool fromStart = false,
  }) {
    final runes = List.from(text.runes, growable: false);
    var numberOfRunesAbove7Bit = 0;
    var startIndex = -1;
    var endIndex = -1;
    final runeCount = runes.length;

    for (var runeIndex = 0; runeIndex < runeCount; runeIndex++) {
      final rune = runes[runeIndex];
      if (rune > 128) {
        numberOfRunesAbove7Bit++;
        if (startIndex == -1) {
          startIndex = runeIndex;
          endIndex = runeIndex;
        } else {
          endIndex = runeIndex;
        }
      }
    }
    if (numberOfRunesAbove7Bit == 0) {
      return text;
    } else {
      // TODO Set the correct encoding
      const qpWordHead = '=?UTF-8?Q?';
      const qpWordTail = '?=';
      const qpWordDelimiterSize = qpWordHead.length + qpWordTail.length;
      if (fromStart) {
        startIndex = 0;
        // the loop below works on runes, not on UTF-16 code units
        endIndex = runeCount - 1;
      }
      // Available space for the current encoded word
      var qpWordSize =
          MailConventions.encodedWordMaxLength -
          qpWordDelimiterSize -
          startIndex -
          (nameLength + 2);
      // Counts the characters of the current encoded word
      var wordCounter = 0;
      // True when reached the end of the current word available space
      var isWordSplit = false;
      final buffer = StringBuffer();
      for (var runeIndex = 0; runeIndex < runeCount; runeIndex++) {
        final rune = runes[runeIndex];
        if (runeIndex < startIndex || runeIndex > endIndex) {
          buffer.writeCharCode(rune);
          continue;
        }
        if (runeIndex == startIndex || isWordSplit) {
          // Adds the line terminator
          if (isWordSplit) {
            buffer
              ..write(qpWordTail)
              // NOTE Per specification, a CRLF should be inserted here,
              // but the folding occurs on the rendering function.
              // Here we leave only the WSP marker to separate each q-encode
              // word.
              // ..writeCharCode(AsciiRunes.runeCarriageReturn)
              // ..writeCharCode(AsciiRunes.runeLineFeed)
              // Assumes per default a single leading space for header folding
              ..writeCharCode(AsciiRunes.runeSpace);
            // Resets the split flag
            isWordSplit = false;
            // Calculates the new encoded word size
            qpWordSize =
                MailConventions.encodedWordMaxLength - qpWordDelimiterSize - 1;
          }
          buffer.write(qpWordHead);
        }
        // " and \ are encoded as well, so that an encoded word can be used
        // inside a quoted-string, e.g. for personal names in addresses
        if ((rune > AsciiRunes.runeSpace &&
                rune <= 60 &&
                rune != AsciiRunes.runeDoubleQuote) ||
            (rune == 62) ||
            (rune > 63 &&
                rune <= 126 &&
                rune != AsciiRunes.runeUnderline &&
                rune != AsciiRunes.runeBackslash)) {
          wordCounter++;
          isWordSplit = wordCounter > qpWordSize;
          if (!isWordSplit) {
            buffer.writeCharCode(rune);
          }
        } else if (rune == AsciiRunes.runeSpace) {
          wordCounter++;
          isWordSplit = wordCounter > qpWordSize;
          if (!isWordSplit) {
            buffer.write('_');
          }
        } else {
          // _writeQuotedPrintable(rune, buffer, codec);
          final quoted = _encodeQuotedPrintableChar(rune, codec);
          wordCounter += quoted.length;
          isWordSplit = wordCounter > qpWordSize;
          if (!isWordSplit) {
            buffer.write(quoted);
          }
        }
        if (isWordSplit) {
          wordCounter = 0;
          runeIndex--;
        }
        if (runeIndex == endIndex) {
          buffer.write(qpWordTail);
        }
      }

      return buffer.toString();
    }
  }

  /// Decodes the specified text
  ///
  /// [part] the text part that should be decoded
  /// [codec] the character encoding (charset)
  /// Set [isHeader] to true to decode header text using the Q-Encoding scheme,
  /// compare https://tools.ietf.org/html/rfc2047#section-4.2
  @override
  String decodeText(
    final String part,
    final Encoding codec, {
    bool isHeader = false,
  }) {
    final buffer = StringBuffer();
    // remove all soft-breaks:
    final cleaned = part.replaceAll('=\r\n', '').replaceAll('=\n', '');
    var i = 0;
    while (i < cleaned.length) {
      final char = cleaned.codeUnitAt(i);
      if (char == AsciiRunes.runeEquals) {
        // collect consecutive =XX sequences so that multi-byte characters
        // are decoded together
        final bytes = <int>[];
        while (i < cleaned.length &&
            cleaned.codeUnitAt(i) == AsciiRunes.runeEquals) {
          final byte = _decodeHexByte(cleaned, i + 1);
          if (byte == null) {
            break;
          }
          bytes.add(byte);
          i += 3;
        }
        if (bytes.isNotEmpty) {
          try {
            buffer.write(codec.decode(bytes));
          } on FormatException catch (err) {
            print('unable to decode quotedPrintable buffer: ${err.message}');
            buffer.write(String.fromCharCodes(bytes));
          }
        } else {
          // RFC 2045 section 6.7: a "=" that is not followed by two hex digits
          // is invalid and is kept as is (robustness)
          buffer.writeCharCode(char);
          i++;
        }
      } else if (isHeader && char == AsciiRunes.runeUnderline) {
        buffer.write(' ');
        i++;
      } else {
        buffer.writeCharCode(char);
        i++;
      }
    }

    return buffer.toString();
  }

  /// Decodes the two hex digits at [index] of [text], or returns `null` if
  /// there are none.
  static int? _decodeHexByte(String text, int index) {
    if (index + 1 >= text.length) {
      return null;
    }
    final high = _hexValue(text.codeUnitAt(index));
    final low = _hexValue(text.codeUnitAt(index + 1));
    if (high == null || low == null) {
      return null;
    }

    return (high << 4) | low;
  }

  static int? _hexValue(int code) {
    if (code >= 48 && code <= 57) {
      return code - 48;
    }
    if (code >= 65 && code <= 70) {
      return code - 55;
    }
    if (code >= 97 && code <= 102) {
      return code - 87;
    }

    return null;
  }

  int _writeQuotedPrintable(int rune, StringBuffer buffer, Codec codec) {
    List<int> encoded;
    if (rune < 128) {
      // this is 7 bit ASCII
      encoded = [rune];
    } else {
      final runeText = String.fromCharCode(rune);
      encoded = codec.encode(runeText);
    }
    final lengthBefore = buffer.length;
    for (final charCode in encoded) {
      final paddedHexValue = charCode.toRadixString(16).toUpperCase();
      buffer.write('=');
      if (paddedHexValue.length == 1) {
        buffer.write('0');
      }
      buffer.write(paddedHexValue);
    }

    return buffer.length - lengthBefore;
  }

  /// Encodes a single rune of a quoted printable word.
  ///
  /// Uses [_writeQuotedPrintable] internally.
  String _encodeQuotedPrintableChar(int rune, Codec codec) {
    final buffer = StringBuffer();
    _writeQuotedPrintable(rune, buffer, codec);

    return buffer.toString();
  }

  /// Decodes quoted-printable content to its raw bytes.
  ///
  /// Unlike [decodeText] this applies no charset: an attachment's bytes are
  /// the message's payload, not text. Returning the undecoded source here,
  /// which is what this used to do, hands the caller `=25PDF=2D1=2E7` where
  /// it asked for `%PDF-1.7`, so every quoted-printable attachment saved or
  /// previewed came out corrupt.
  @override
  Uint8List decodeData(String part) {
    // Soft line breaks carry no data.
    final cleaned = part.replaceAll('=\r\n', '').replaceAll('=\n', '');
    final out = Uint8List(cleaned.length);
    var length = 0;
    for (var i = 0; i < cleaned.length; i++) {
      final codeUnit = cleaned.codeUnitAt(i);
      if (codeUnit == AsciiRunes.runeEquals && i + 2 < cleaned.length) {
        final byte = int.tryParse(cleaned.substring(i + 1, i + 3), radix: 16);
        if (byte != null) {
          out[length++] = byte;
          i += 2;
          continue;
        }
      }
      out[length++] = codeUnit & 0xFF;
    }

    return Uint8List.sublistView(out, 0, length);
  }
}
