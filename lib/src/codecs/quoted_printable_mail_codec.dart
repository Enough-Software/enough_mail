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
  String encodeText(final String text,
      {Codec codec = MailCodec.encodingUtf8, bool wrap = true}) {
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
  String encodeHeader(final String text,
      {int nameLength = 0, Codec codec = utf8, bool fromStart = false}) {
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
      const qpWordHead = '=?utf8?Q?';
      const qpWordTail = '?=';
      const qpWordDelimiterSize = qpWordHead.length + qpWordTail.length;
      if (fromStart) {
        startIndex = 0;
        endIndex = text.length - 1;
      }
      // Available space for the current encoded word
      var qpWordSize = MailConventions.encodedWordMaxLength -
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
        if ((rune > AsciiRunes.runeSpace && rune <= 60) ||
            (rune == 62) ||
            (rune > 63 && rune <= 126 && rune != AsciiRunes.runeUnderline)) {
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
  String decodeText(final String part, final Encoding codec,
      {bool isHeader = false}) {
    final buffer = StringBuffer();
    // remove all soft-breaks:
    final cleaned = part.replaceAll('=\r\n', '');
    for (var i = 0; i < cleaned.length; i++) {
      final char = cleaned[i];
      if (char == '=') {
        final hexText = cleaned.substring(i + 1, i + 3);
        var charCode = int.tryParse(hexText, radix: 16);
        if (charCode == null) {
          print('unable to decode quotedPrintable [$cleaned]: '
              'invalid hex code [$hexText] at $i.');
          buffer.write(hexText);
        } else {
          final charCodes = [charCode];
          while (cleaned.length > (i + 4) && cleaned[i + 3] == '=') {
            i += 3;
            final hexText = cleaned.substring(i + 1, i + 3);
            charCode = int.parse(hexText, radix: 16);
            charCodes.add(charCode);
          }

          try {
            final decoded = codec.decode(charCodes);
            buffer.write(decoded);
          } on FormatException catch (err) {
            print('unable to decode quotedPrintable buffer: ${err.message}');
            buffer.write(String.fromCharCodes(charCodes));
          }
        }
        i += 2;
      } else if (isHeader && char == '_') {
        buffer.write(' ');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
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

  @override
  Uint8List decodeData(String part) => Uint8List.fromList(part.codeUnits);
}
