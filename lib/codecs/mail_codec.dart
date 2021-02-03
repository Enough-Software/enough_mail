import 'dart:convert' as convert;

import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';
import 'package:enough_mail/mail_conventions.dart';
import 'package:enough_mail/src/util/ascii_runes.dart';

import 'quoted_printable_mail_codec.dart';
import 'base64_mail_codec.dart';

/// Encodes and decodes base-64 and quoted printable encoded texts
/// Compare https://tools.ietf.org/html/rfc2045#page-19
/// and https://tools.ietf.org/html/rfc2045#page-23 for details
abstract class MailCodec {
  static const String contentTransferEncodingNone = 'none';

  /// Typical maximum length of a single text line
  static const String _encodingEndSequence = '?=';
  static final RegExp _encodingExpression = RegExp(
      r'\=\?.+?\?.+?\?.+?\?\='); // the question marks after plus make this regular expression non-greedy
  static const convert.Encoding encodingUtf8 =
      convert.Utf8Codec(allowMalformed: true);
  static const convert.Encoding encodingLatin1 =
      Latin1Codec(allowInvalid: true);
  static const convert.Encoding encodingAscii = convert.ascii;
  static final Map<String, convert.Encoding> _codecsByName =
      <String, convert.Encoding>{
    'utf-8': encodingUtf8,
    'utf8': encodingUtf8,
    'latin-1': encodingLatin1,
    'iso-8859-1': encodingLatin1,
    'iso-8859-2': const Latin2Codec(),
    'iso-8859-3': const Latin3Codec(),
    'iso-8859-4': const Latin4Codec(),
    'iso-8859-5': const Latin5Codec(),
    'iso-8859-6': const Latin6Codec(),
    'iso-8859-7': const Latin7Codec(),
    'iso-8859-8': const Latin8Codec(),
    'iso-8859-9': const Latin9Codec(),
    'iso-8859-10': const Latin10Codec(),
    'iso-8859-11': const Latin11Codec(),
    // iso-8859-12 does not exist...
    'iso-8859-13': const Latin13Codec(),
    'iso-8859-14': const Latin14Codec(),
    'iso-8859-15': const Latin15Codec(),
    'iso-8859-16': const Latin16Codec(),
    'windows-1250': const Windows1250Codec(),
    'cp1250': const Windows1250Codec(),
    'windows-1251': const Windows1251Codec(),
    'cp1251': const Windows1251Codec(),
    'windows-1252': const Windows1252Codec(),
    'cp1252': const Windows1252Codec(),
    'us-ascii': convert.ascii,
    'ascii': convert.ascii
  };
  static final Map<
      String,
      String Function(String text, convert.Encoding encoding,
          {bool isHeader})> _textDecodersByName = <String,
      String Function(String text, convert.Encoding encoding, {bool isHeader})>{
    'q': quotedPrintable.decodeText,
    'quoted-printable': quotedPrintable.decodeText,
    'b': base64.decodeText,
    'base64': base64.decodeText,
    'base-64': base64.decodeText,
    '7bit': decodeOnlyCodec,
    '8bit': decodeOnlyCodec,
    contentTransferEncodingNone: decodeOnlyCodec
  };

  static final Map<String, Uint8List Function(String)> _binaryDecodersByName =
      <String, Uint8List Function(String)>{
    'b': base64.decodeData,
    'base64': base64.decodeData,
    'base-64': base64.decodeData,
    'binary': decodeBinaryTextData,
    '8bit': decode8BitTextData,
    contentTransferEncodingNone: decode8BitTextData
  };

  static const base64 = Base64MailCodec();
  static const quotedPrintable = QuotedPrintableMailCodec();

  const MailCodec();

  /// Encodes the specified text in the chosen codec's format.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set [wrap] to false in case you do not want to wrap lines.
  String encodeText(String text,
      {convert.Codec codec = encodingUtf8, bool wrap = true});

  /// Encodes the header text in the chosen codec's only if required.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set the optional [fromStart] to true in case the encoding should  start at the beginning of the text and not in the middle.
  String encodeHeader(String text, {bool fromStart = false});
  Uint8List decodeData(String part);
  String decodeText(String part, convert.Encoding codec,
      {bool isHeader = false});

  static String decodeHeader(String input) {
    if (input == null || input.isEmpty) {
      return input;
    }
    // remove any spaces between 2 encoded words:
    if (input.contains('?= =?')) {
      final match = _encodingExpression.firstMatch(input);
      if (match != null) {
        final sequence = match.group(0);
        final separatorIndex = sequence.indexOf('?', 3);
        final endIndex = separatorIndex + 3;
        final startSequence = sequence.substring(0, endIndex);
        input = input.replaceAll('?= $startSequence', '');
      }
    }
    final buffer = StringBuffer();
    _decodeHeaderImpl(input, buffer);
    return buffer.toString();
  }

  static void _decodeHeaderImpl(String input, StringBuffer buffer) {
    RegExpMatch match;
    while ((match = _encodingExpression.firstMatch(input)) != null) {
      final sequence = match.group(0);
      final separatorIndex = sequence.indexOf('?', 3);
      final characterEncodingName =
          sequence.substring('=?'.length, separatorIndex).toLowerCase();
      final decoderName = sequence
          .substring(separatorIndex + 1, separatorIndex + 2)
          .toLowerCase();

      final codec = _codecsByName[characterEncodingName];
      if (codec == null) {
        print('Error: no encoding found for [$characterEncodingName].');
        buffer.write(input);
        return;
      }
      final decoder = _textDecodersByName[decoderName];
      if (decoder == null) {
        print('Error: no decoder found for [$decoderName].');
        buffer.write(input);
        return;
      }
      if (match.start > 0) {
        buffer.write(input.substring(0, match.start));
      }
      final contentStartIndex = separatorIndex + 3;
      final part = sequence.substring(
          contentStartIndex, sequence.length - _encodingEndSequence.length);
      final decoded = decoder(part, codec, isHeader: true);
      buffer.write(decoded);
      input = input.substring(match.end);
    }
    buffer.write(input);
  }

  static Uint8List decodeBinary(String text, String transferEncoding) {
    transferEncoding ??= contentTransferEncodingNone;
    final decoder = _binaryDecodersByName[transferEncoding.toLowerCase()];
    if (decoder == null) {
      print('Error: no binary decoder found for [$transferEncoding].');
      return Uint8List.fromList(text.codeUnits);
    }
    return decoder(text);
  }

  static String decodeAnyText(
      String text, String transferEncoding, String characterEncoding) {
    transferEncoding ??= contentTransferEncodingNone;
    characterEncoding ??= 'utf8';
    final codec = _codecsByName[characterEncoding.toLowerCase()];
    final decoder = _textDecodersByName[transferEncoding.toLowerCase()];
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
    return Uint8List.fromList(part.codeUnits);
  }

  static Uint8List decode8BitTextData(String part) {
    part = part.replaceAll('\r\n', '');
    return Uint8List.fromList(part.codeUnits);
  }

  static String decodeOnlyCodec(String part, convert.Encoding codec,
      {bool isHeader = false}) {
    //TODO does decoding code units even make sense??
    if (codec == encodingUtf8 || codec == encodingAscii) {
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
    final buffer = StringBuffer();
    final runes = text.runes;
    int lastRune;
    int lastSpaceIndex;
    var currentLineLength = 0;
    var currentLineStartIndex = 0;
    for (var runeIndex = 0; runeIndex < runes.length; runeIndex++) {
      final rune = runes.elementAt(runeIndex);
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
    // final currentIndex = 0;
    // while (currentIndex + MailConventions.textLineMaxLength < text.length) {
    //   final length = MailConventions.textLineMaxLength;
    //   if (wrapAtWordBoundary) {
    //     final endIndex = currentIndex + MailConventions.textLineMaxLength - 1;
    //     final runes = text.runes;
    //     final rune = runes.elementAt(endIndex);
    //     if (rune != AsciiRunes.runeSpace) {
    //       for (final runeIndex = endIndex; --runeIndex > currentIndex;) {
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
