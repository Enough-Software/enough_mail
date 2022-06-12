import 'dart:convert' as convert;
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';

import '../mail_conventions.dart';
import '../private/util/ascii_runes.dart';
import 'base64_mail_codec.dart';
import 'quoted_printable_mail_codec.dart';

/// The used header encoding mechanism
enum HeaderEncoding {
  /// Q encoding similar to QuotedPrintable
  Q,

  /// Base64 encoding
  B,

  /// No encoding
  none
}

/// Encodes and decodes base-64 and quoted printable encoded texts
///
/// Compare https://tools.ietf.org/html/rfc2045#page-19
/// and https://tools.ietf.org/html/rfc2045#page-23 for details
abstract class MailCodec {
  /// Creates a new mail codec
  const MailCodec();

  /// No transfer encoding
  static const String contentTransferEncodingNone = 'none';

  /// Typical maximum length of a single text line
  static const String _encodingEndSequence = '?=';
  static final _headerEncodingExpression = RegExp(
      r'\=\?.+?\?.+?\?.+?\?\='); // the question marks after plus make this regular expression non-greedy
  static final _emptyHeaderEncodingExpression = RegExp(r'\=\?.+?\?.+?\?\?\=');

  /// UTF8 encoding
  static const encodingUtf8 = convert.Utf8Codec(allowMalformed: true);

  /// ISO-8859-1 encoding
  static const encodingLatin1 = convert.Latin1Codec(allowInvalid: true);

  /// ASCII encoding
  static const encodingAscii = convert.AsciiCodec(allowInvalid: true);
  static final _charsetCodecsByName = <String, convert.Encoding Function()>{
    'utf-8': () => encodingUtf8,
    'utf8': () => encodingUtf8,
    'latin-1': () => encodingLatin1,
    'iso-8859-1': () => encodingLatin1,
    'iso-8859-2': () => const Latin2Codec(allowInvalid: true),
    'iso-8859-3': () => const Latin3Codec(allowInvalid: true),
    'iso-8859-4': () => const Latin4Codec(allowInvalid: true),
    'iso-8859-5': () => const Latin5Codec(allowInvalid: true),
    'iso-8859-6': () => const Latin6Codec(allowInvalid: true),
    'iso-8859-7': () => const Latin7Codec(allowInvalid: true),
    'iso-8859-8': () => const Latin8Codec(allowInvalid: true),
    'iso-8859-9': () => const Latin9Codec(allowInvalid: true),
    'iso-8859-10': () => const Latin10Codec(allowInvalid: true),
    'iso-8859-11': () => const Latin11Codec(allowInvalid: true),
    // iso-8859-12 does not exist...
    'iso-8859-13': () => const Latin13Codec(allowInvalid: true),
    'iso-8859-14': () => const Latin14Codec(allowInvalid: true),
    'iso-8859-15': () => const Latin15Codec(allowInvalid: true),
    'iso-8859-16': () => const Latin16Codec(allowInvalid: true),
    'windows-1250': () => const Windows1250Codec(allowInvalid: true),
    'cp1250': () => const Windows1250Codec(allowInvalid: true),
    'cp-1250': () => const Windows1250Codec(allowInvalid: true),
    'windows-1251': () => const Windows1251Codec(allowInvalid: true),
    'cp1251': () => const Windows1251Codec(allowInvalid: true),
    'windows-1252': () => const Windows1252Codec(allowInvalid: true),
    'cp1252': () => const Windows1252Codec(allowInvalid: true),
    'cp-1252': () => const Windows1252Codec(allowInvalid: true),
    'windows-1253': () => const Windows1253Codec(allowInvalid: true),
    'cp1253': () => const Windows1253Codec(allowInvalid: true),
    'cp-1253': () => const Windows1253Codec(allowInvalid: true),
    'windows-1254': () => const Windows1254Codec(allowInvalid: true),
    'cp1254': () => const Windows1254Codec(allowInvalid: true),
    'cp-1254': () => const Windows1254Codec(allowInvalid: true),
    'windows-1256': () => const Windows1256Codec(allowInvalid: true),
    'cp1256': () => const Windows1256Codec(allowInvalid: true),
    'cp-1256': () => const Windows1256Codec(allowInvalid: true),
    'gbk': () => const GbkCodec(allowInvalid: true),
    'gb2312': () => const GbkCodec(allowInvalid: true),
    'gb-2312': () => const GbkCodec(allowInvalid: true),
    'cp-936': () => const GbkCodec(allowInvalid: true),
    'windows-936': () => const GbkCodec(allowInvalid: true),
    'gb18030': () => const GbkCodec(allowInvalid: true),
    'chinese': () => const GbkCodec(allowInvalid: true),
    'csgb2312': () => const GbkCodec(allowInvalid: true),
    'csgb231280': () => const GbkCodec(allowInvalid: true),
    'csiso58gb231280': () => const GbkCodec(allowInvalid: true),
    'iso-ir-58': () => const GbkCodec(allowInvalid: true),
    'x-mac-chinesesimp': () => const GbkCodec(allowInvalid: true),
    'big5': () => const Big5Codec(allowInvalid: true),
    'big-5': () => const Big5Codec(allowInvalid: true),
    'koi8': () => const Koi8rCodec(allowInvalid: true),
    'koi8-r': () => const Koi8rCodec(allowInvalid: true),
    'koi8-u': () => const Koi8uCodec(allowInvalid: true),
    'us-ascii': () => encodingAscii,
    'ascii': () => encodingAscii,
  };
  static final _textDecodersByName = <
      String,
      String Function(String text, convert.Encoding encoding,
          {required bool isHeader})>{
    'q': quotedPrintable.decodeText,
    'quoted-printable': quotedPrintable.decodeText,
    'b': base64.decodeText,
    'base64': base64.decodeText,
    'base-64': base64.decodeText,
    '7bit': decodeOnlyCodec,
    '8bit': decodeOnlyCodec,
    contentTransferEncodingNone: decodeOnlyCodec
  };

  static final _binaryDecodersByName = <String, Uint8List Function(String)>{
    'b': base64.decodeData,
    'base64': base64.decodeData,
    'base-64': base64.decodeData,
    'binary': decodeBinaryTextData,
    '8bit': decode8BitTextData,
    contentTransferEncodingNone: decode8BitTextData
  };

  /// bas64 mail codec
  static const base64 = Base64MailCodec();

  /// quoted printable mail codec
  static const quotedPrintable = QuotedPrintableMailCodec();

  /// Encodes the specified text in the chosen codec's format.
  ///
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set [wrap] to false in case you do not want to wrap lines.
  String encodeText(String text,
      {convert.Codec codec = encodingUtf8, bool wrap = true});

  /// Encodes the header text in the chosen codec's only if required.
  ///
  /// [text] specifies the text to be encoded.
  /// Set the optional [fromStart] to true in case the encoding should
  /// start at the beginning of the text and not in the middle.
  String encodeHeader(String text, {bool fromStart = false});

  /// Encodes the given [part] text.
  Uint8List decodeData(String part);

  /// Decodes the given [part] text with the given [codec].
  ///
  /// [isHeader] is set to the `true` when this text originates from a header
  String decodeText(String part, convert.Encoding codec,
      {bool isHeader = false});

  /// Decodes the given header [input] value.
  static String? decodeHeader(final String? input) {
    if (input == null || input.isEmpty) {
      return input;
    }
    // unwrap any lines:
    var cleaned = input.replaceAll('\r\n ', '');
    // remove any spaces between 2 encoded words:
    final containsEncodedWordsWithSpace = cleaned.contains('?= =?');
    final containsEncodedWordsWithTab = cleaned.contains('?=\t=?');
    final containsEncodedWordsWithoutSpace =
        !containsEncodedWordsWithSpace && cleaned.contains('?==?');
    if (containsEncodedWordsWithSpace ||
        containsEncodedWordsWithTab ||
        containsEncodedWordsWithoutSpace) {
      final match = _headerEncodingExpression.firstMatch(cleaned);
      if (match != null) {
        final sequence = match.group(0)!;
        final separatorIndex = sequence.indexOf('?', 3);
        final endIndex = separatorIndex + 3;
        final startSequence = sequence.substring(0, endIndex);
        final searchText = containsEncodedWordsWithSpace
            ? '?= $startSequence'
            : containsEncodedWordsWithTab
                ? '?=\t$startSequence'
                : '?=$startSequence';
        if (startSequence.endsWith('?B?')) {
          // in base64 encoding there are 2 cases:
          // 1. individual parts can end  with the padding character "=":
          //    - in that case we just remove the
          //      space between the encoded words
          // 2. individual words do not end with a padding character:
          //    - in that case we combine the words
          if (cleaned.contains('=$searchText')) {
            if (containsEncodedWordsWithSpace) {
              cleaned = cleaned.replaceAll('?= =?', '?==?');
            } else if (containsEncodedWordsWithTab) {
              cleaned = cleaned.replaceAll('?=\t=?', '?==?');
            }
          } else {
            cleaned = cleaned.replaceAll(searchText, '');
          }
        } else {
          // "standard case" - just fuse the sequences together
          cleaned = cleaned.replaceAll(searchText, '');
        }
      }
    }
    final buffer = StringBuffer();
    _decodeHeaderImpl(cleaned, buffer);
    return buffer.toString();
  }

  static void _decodeHeaderImpl(final String input, StringBuffer buffer) {
    RegExpMatch? match;
    var reminder = input;
    while ((match = _headerEncodingExpression.firstMatch(reminder)) != null) {
      final sequence = match!.group(0)!;
      final separatorIndex = sequence.indexOf('?', 3);
      final characterEncodingName =
          sequence.substring('=?'.length, separatorIndex).toLowerCase();
      final decoderName = sequence
          .substring(separatorIndex + 1, separatorIndex + 2)
          .toLowerCase();

      final codec = _charsetCodecsByName[characterEncodingName]?.call();
      if (codec == null) {
        print('Error: no encoding found for [$characterEncodingName].');
        buffer.write(reminder);
        return;
      }
      final decoder = _textDecodersByName[decoderName];
      if (decoder == null) {
        print('Error: no decoder found for [$decoderName].');
        buffer.write(reminder);
        return;
      }
      if (match.start > 0) {
        buffer.write(reminder.substring(0, match.start));
      }
      final contentStartIndex = separatorIndex + 3;
      final part = sequence.substring(
          contentStartIndex, sequence.length - _encodingEndSequence.length);
      final decoded = decoder(part, codec, isHeader: true);
      buffer.write(decoded);
      reminder = reminder.substring(match.end);
    }
    if (buffer.isEmpty &&
        reminder.startsWith('=?') &&
        _emptyHeaderEncodingExpression.hasMatch(reminder)) {
      return;
    }
    buffer.write(reminder);
  }

  /// Detects the encoding used in the given header [value].
  static HeaderEncoding detectHeaderEncoding(String value) {
    final match = _headerEncodingExpression.firstMatch(value);
    if (match == null) {
      return HeaderEncoding.none;
    }
    final group = match.group(0);
    if (group?.contains('?B?') ?? false) {
      return HeaderEncoding.B;
    }
    return HeaderEncoding.Q;
  }

  /// Decodes the given binary [text]
  static Uint8List decodeBinary(
      final String text, final String? transferEncoding) {
    final tEncoding = transferEncoding ?? contentTransferEncodingNone;
    final decoder = _binaryDecodersByName[tEncoding.toLowerCase()];
    if (decoder == null) {
      print('Error: no binary decoder found for [$tEncoding].');
      return Uint8List.fromList(text.codeUnits);
    }
    return decoder(text);
  }

  /// Decodes the given [data]
  static String decodeAsText(final Uint8List data,
      final String? transferEncoding, final String? charset) {
    if (transferEncoding == null && charset == null) {
      // this could be a) UTF-8 or b) UTF-16 most likely:
      final utf8Decoded = encodingUtf8.decode(data, allowMalformed: true);
      if (utf8Decoded.contains('�')) {
        final comparison = String.fromCharCodes(data);
        if (!comparison.contains('�')) {
          return comparison;
        }
      }
      return utf8Decoded;
    }
    // there is actually just one interesting case:
    // when the transfer encoding is 8bit, the text needs to be decoded with
    // the specified charset.
    // Note that some mail senders also declare 7bit message encoding even when
    // UTF8 or other 8bit encodings are used.
    // In other cases the text is ASCII and the 'normal' decodeAnyText method
    // can be used.
    final transferEncodingLC = transferEncoding?.toLowerCase() ?? '8bit';
    if (transferEncodingLC == '8bit' ||
        transferEncodingLC == '7bit' ||
        transferEncodingLC == 'binary') {
      final cs = charset ?? 'utf8';
      final codec = _charsetCodecsByName[cs.toLowerCase()]?.call();
      if (codec == null) {
        print('Error: no encoding found for charset [$cs].');
        return encodingUtf8.decode(data, allowMalformed: true);
      }
      final decodedText = codec.decode(data);
      return decodedText;
    }
    final text = String.fromCharCodes(data);
    return decodeAnyText(text, transferEncoding, charset);
  }

  /// Decodes the given [text]
  static String decodeAnyText(final String text, final String? transferEncoding,
      final String? charset) {
    final transferEnc = transferEncoding ?? contentTransferEncodingNone;
    final decoder = _textDecodersByName[transferEnc.toLowerCase()];
    if (decoder == null) {
      print('Error: no decoder found for '
          'content-transfer-encoding [$transferEnc].');
      return text;
    }
    final cs = charset ?? 'utf8';
    final codec = _charsetCodecsByName[cs.toLowerCase()]?.call();
    if (codec == null) {
      print('Error: no encoding found for charset [$cs].');
      return text;
    }
    return decoder(text, codec, isHeader: false);
  }

  /// Decodes binary from the given text [part].
  static Uint8List decodeBinaryTextData(String part) =>
      Uint8List.fromList(part.codeUnits);

  /// Decodes the data from the given 8bit text [part]
  static Uint8List decode8BitTextData(final String part) =>
      Uint8List.fromList(part.replaceAll('\r\n', '').codeUnits);

  /// Is a noop
  static String decodeOnlyCodec(String part, convert.Encoding codec,
          {bool isHeader = false}) =>
      part;

  /// Wraps the text so that it stays within email's 76 characters
  /// per line convention.
  ///
  /// [text] the text that should be wrapped.
  /// Set [wrapAtWordBoundary] to true in case the text should be wrapped
  /// at word boundaries / spaces.
  static String wrapText(String text, {bool wrapAtWordBoundary = false}) {
    if (text.length <= MailConventions.textLineMaxLength) {
      return text;
    }
    final buffer = StringBuffer();
    final runes = text.runes;
    int? lastRune;
    int? lastSpaceIndex;
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
          buffer
            ..write(text.substring(currentLineStartIndex, endIndex))
            ..write('\r\n');
          currentLineLength = 0;
          currentLineStartIndex = endIndex;
          lastSpaceIndex = null;
        }
      }
      lastRune = rune;
    }

    if (currentLineStartIndex < text.length) {
      buffer.write(text.substring(currentLineStartIndex));
    }
    return buffer.toString();
  }
}
