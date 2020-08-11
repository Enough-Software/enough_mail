import 'dart:convert';

import 'dart:typed_data';

import 'package:enough_mail/mail_conventions.dart';
import 'package:enough_mail/src/util/ascii_runes.dart';

import 'quoted_printable_mail_codec.dart';
import 'base64_mail_codec.dart';

/// Encodes and decodes base-64 and quoted printable encoded texts
/// Compare https://tools.ietf.org/html/rfc2045#page-19
/// and https://tools.ietf.org/html/rfc2045#page-23 for details
abstract class MailCodec {
  /// Typical maximum length of a single text line
  static const String _encodingEndSequence = '?=';
  static final RegExp _encodingExpression = RegExp(
      r'\=\?.+?\?.+?\?.+?\?\='); // the question marks after plus make this regular expression non-greedy
  static const Encoding encodingUtf8 = utf8;
  static const Encoding encodingLatin1 = latin1;
  static const Encoding encodingAscii = ascii;
  static final Map<String, Encoding> _codecsByName = <String, Encoding>{
    'utf-8': utf8,
    'utf8': utf8,
    'latin-1': latin1,
    'iso-8859-1': latin1,
    'iso-8859-2': utf8, //TODO add proper character encoding support
    'iso-8859-3': utf8, //TODO add proper character encoding support
    'iso-8859-4': utf8, //TODO add proper character encoding support
    'iso-8859-5': utf8, //TODO add proper character encoding support
    'iso-8859-6': utf8, //TODO add proper character encoding support
    'iso-8859-7': utf8, //TODO add proper character encoding support
    'iso-8859-8': utf8, //TODO add proper character encoding support
    'iso-8859-9': utf8, //TODO add proper character encoding support
    'iso-8859-10': utf8, //TODO add proper character encoding support
    'iso-8859-11': utf8, //TODO add proper character encoding support
    'iso-8859-12': utf8, //TODO add proper character encoding support
    'iso-8859-13': utf8, //TODO add proper character encoding support
    'iso-8859-14': utf8, //TODO add proper character encoding support
    'iso-8859-15': utf8, //TODO add proper character encoding support
    'iso-8859-16': utf8, //TODO add proper character encoding support
    'us-ascii': ascii,
    'ascii': ascii
  };
  static final Map<String,
          String Function(String text, Encoding encoding, {bool isHeader})>
      _textDecodersByName = <String,
          String Function(String text, Encoding encoding, {bool isHeader})>{
    'q': quotedPrintable.decodeText,
    'quoted-printable': quotedPrintable.decodeText,
    'b': base64.decodeText,
    'base64': base64.decodeText,
    'base-64': base64.decodeText,
    '7bit': decodeOnlyCodec,
    '8bit': decodeOnlyCodec,
    'none': decodeOnlyCodec
  };

  static final Map<String, Uint8List Function(String)> _binaryDecodersByName =
      <String, Uint8List Function(String)>{
    'b': base64.decodeData,
    'base64': base64.decodeData,
    'base-64': base64.decodeData,
    'binary': decodeBinaryTextData,
    '8bit': decode8BitTextData,
    'none': decode8BitTextData
  };

  static const base64 = Base64MailCodec();
  static const quotedPrintable = QuotedPrintableMailCodec();

  const MailCodec();

  /// Encodes the specified text in the chosen codec's format.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set [wrap] to false in case you do not want to wrap lines.
  String encodeText(String text, {Codec codec = utf8, bool wrap = true});

  /// Encodes the header text in the chosen codec's only if required.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set the optional [fromStart] to true in case the encoding should  start at the beginning of the text and not in the middle.
  String encodeHeader(String text, {bool fromStart = false});
  Uint8List decodeData(String part);
  String decodeText(String part, Encoding codec, {bool isHeader = false});

  static String decodeHeader(String input) {
    if (input == null || input.isEmpty) {
      return input;
    }
    var buffer = StringBuffer();
    _decodeHeaderImpl(input, buffer);
    return buffer.toString();
  }

  static void _decodeHeaderImpl(String input, StringBuffer buffer) {
    RegExpMatch match;
    while ((match = _encodingExpression.firstMatch(input)) != null) {
      var sequence = match.group(0);
      var separatorIndex = sequence.indexOf('?', 3);
      var characterEncodingName =
          sequence.substring('=?'.length, separatorIndex).toLowerCase();
      var decoderName = sequence
          .substring(separatorIndex + 1, separatorIndex + 2)
          .toLowerCase();

      var codec = _codecsByName[characterEncodingName];
      if (codec == null) {
        print('Error: no encoding found for [$characterEncodingName].');
        buffer.write(input);
        return;
      }
      var decoder = _textDecodersByName[decoderName];
      if (decoder == null) {
        print('Error: no decoder found for [$decoderName].');
        buffer.write(input);
        return;
      }
      if (match.start > 0) {
        buffer.write(input.substring(0, match.start));
      }
      var contentStartIndex = separatorIndex + 3;
      var part = sequence.substring(
          contentStartIndex, sequence.length - _encodingEndSequence.length);
      var decoded = decoder(part, codec, isHeader: true);
      buffer.write(decoded);
      input = input.substring(match.end);
    }
    buffer.write(input);
  }

  static Uint8List decodeBinary(String text, String transferEncoding) {
    transferEncoding ??= 'none';
    var decoder = _binaryDecodersByName[transferEncoding.toLowerCase()];
    if (decoder == null) {
      print('Error: no binrary decoder found for [$transferEncoding].');
      return text.codeUnits;
    }
    return decoder(text);
  }

  static String decodeAnyText(
      String text, String transferEncoding, String characterEncoding) {
    transferEncoding ??= 'none';
    characterEncoding ??= 'utf8';
    var codec = _codecsByName[characterEncoding.toLowerCase()];
    var decoder = _textDecodersByName[transferEncoding.toLowerCase()];
    if (decoder == null) {
      print('Error: no decoder found for [$transferEncoding].');
      return text;
    }
    if (codec == null) {
      print('Error: no encoding found for [$characterEncoding].');
      return text;
    }
    return decoder(text, codec);
  }

  static Uint8List decodeBinaryTextData(String part) {
    return part.codeUnits;
  }

  static Uint8List decode8BitTextData(String part) {
    part = part.replaceAll('\r\n', '');
    return part.codeUnits;
  }

  static String decodeOnlyCodec(String part, Encoding codec,
      {bool isHeader = false}) {
    //TODO does decoding code units even make sense??
    if (codec == utf8) {
      return part;
    }
    return codec.decode(part.codeUnits);
  }

  /// Wraps the text so that it stays within email's 76 characters per line convention.
  /// [text] the text that should be wrapped.
  /// Set [wrapAtWordBoundary] to true in case the text should be wrapped at word boundaries / spaces.
  static String wrapText(String text, {bool wrapAtWordBoundary = false}) {
    if (text.length <= MailConventions.textLineMaxLength) {
      return text;
    }
    var buffer = StringBuffer();
    var runes = text.runes;
    int lastRune;
    int lastSpaceIndex;
    var currentLineLength = 0;
    var currentLineStartIndex = 0;
    for (var runeIndex = 0; runeIndex < runes.length; runeIndex++) {
      var rune = runes.elementAt(runeIndex);
      if (rune == AsciiRunes.runeLineFeed &&
          lastRune == AsciiRunes.runeCarriageReturn) {
        buffer.write(text.substring(currentLineStartIndex, runeIndex + 1));
        currentLineLength = 0;
        currentLineStartIndex = runeIndex + 1;
        lastSpaceIndex = null;
      } else {
        if (wrapAtWordBoundary &&
            (rune == AsciiRunes.runeSpace || rune == AsciiRunes.runeTab)) {
          lastSpaceIndex = runeIndex;
        }
        currentLineLength++;
        if (currentLineLength >= MailConventions.textLineMaxLength) {
          // edge case: this could be in the middle of a \r\n sequence:
          if (rune == AsciiRunes.runeCarriageReturn &&
              runeIndex < runes.length - 1 &&
              runes.elementAt(runeIndex + 1) == AsciiRunes.runeLineFeed) {
            lastRune = rune;
            continue; // the break will be handled in the next loop iteration
          }
          var endIndex = (wrapAtWordBoundary && lastSpaceIndex != null)
              ? lastSpaceIndex
              : runeIndex;
          if (endIndex < runes.length - 1) {
            endIndex++;
          }
          buffer.write(text.substring(currentLineStartIndex, endIndex));
          buffer.write('\r\n');
          currentLineLength = 0;
          currentLineStartIndex = endIndex;
          lastSpaceIndex = null;
        }
      }
      lastRune = rune;
    }
    // var currentIndex = 0;
    // while (currentIndex + MailConventions.textLineMaxLength < text.length) {
    //   var length = MailConventions.textLineMaxLength;
    //   if (wrapAtWordBoundary) {
    //     var endIndex = currentIndex + MailConventions.textLineMaxLength - 1;
    //     var runes = text.runes;
    //     var rune = runes.elementAt(endIndex);
    //     if (rune != AsciiRunes.runeSpace) {
    //       for (var runeIndex = endIndex; --runeIndex > currentIndex;) {
    //         rune = runes.elementAt(runeIndex);
    //         if (rune == AsciiRunes.runeSpace) {
    //           endIndex = runeIndex;
    //           break;
    //         }
    //       }
    //     }
    //     length = endIndex - currentIndex + 1;
    //   }
    //   buffer.write(text.substring(currentIndex, currentIndex + length));
    //   buffer.write('\r\n');
    //   currentIndex += length;
    // }
    if (currentLineStartIndex < text.length) {
      buffer.write(text.substring(currentLineStartIndex));
    }
    return buffer.toString();
  }
}
