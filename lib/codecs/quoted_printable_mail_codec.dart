import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail_conventions.dart';

/// Provides quoted printable encoder and decoder.
/// Compare https://tools.ietf.org/html/rfc2045#page-19 for details.
class QuotedPrintableMailCodec extends MailCodec {
  const QuotedPrintableMailCodec();

  /// Encodes the specified text in quoted printable format.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set [wrap] to false in case you do not want to wrap lines.
  @override
  String encodeText(String text, {Codec codec = utf8, bool wrap = true}) {
    var buffer = StringBuffer();
    var lineCharacterCount = 0;
    for (var rune in text.runes) {
      if ((rune >= 32 && rune <= 60) ||
          (rune >= 62 && rune <= 126) ||
          rune == 9) {
        buffer.writeCharCode(rune);
        lineCharacterCount++;
      } else {
        _writeQuotedPrintable(rune, buffer, codec);
      }
      if (wrap && lineCharacterCount >= MailConventions.textLineMaxLength) {
        buffer.write('=\r\n'); // soft line break
        lineCharacterCount = 0;
      }
    }
    return buffer.toString();
  }

  /// Encodes the header text in quoted printable only if required.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set the optional [fromStart] to true in case the encoding should  start at the beginning of the text and not in the middle.
  @override
  String encodeHeader(String text,
      {Codec codec = utf8, bool fromStart = false}) {
    var runes = text.runes;
    var numberOfRunesAbove7Bit = 0;
    var startIndex = -1;
    var endIndex = -1;
    for (var runeIndex = 0; runeIndex < runes.length; runeIndex++) {
      var rune = runes.elementAt(runeIndex);
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
      if (fromStart) {
        startIndex = 0;
        endIndex = text.length - 1;
      }
      var buffer = StringBuffer();
      for (var runeIndex = 0; runeIndex < runes.length; runeIndex++) {
        var rune = runes.elementAt(runeIndex);
        if (runeIndex < startIndex || runeIndex > endIndex) {
          buffer.writeCharCode(rune);
          continue;
        }
        if (runeIndex == startIndex) {
          buffer.write('=?utf8?Q?');
        }
        if ((rune >= 32 && rune <= 60) ||
            (rune >= 62 && rune <= 126) ||
            rune == 9) {
          buffer.writeCharCode(rune);
        } else {
          _writeQuotedPrintable(rune, buffer, codec);
        }
        if (runeIndex == endIndex) {
          buffer.write('?=');
        }
      }
      return buffer.toString();
    }
  }

  /// Decodes the specified text
  ///
  /// [part] the text part that should be decoded
  /// [codec] the character encoding (charset)
  @override
  String decodeText(String part, Encoding codec) {
    var buffer = StringBuffer();
    // remove all soft-breaks:
    part = part.replaceAll('=\r\n', '');
    for (var i = 0; i < part.length; i++) {
      var char = part[i];
      if (char == '=') {
        var hexText = part.substring(i + 1, i + 3);
        var charCode = int.tryParse(hexText, radix: 16);
        if (charCode == null) {
          print(
              'unable to decode quotedPrintable [$part]: invalid hex code [$hexText] at $i.');
          buffer.write(hexText);
        } else {
          var charCodes = [charCode];
          while (part.length > (i + 4) && part[i + 3] == '=') {
            i += 3;
            var hexText = part.substring(i + 1, i + 3);
            charCode = int.parse(hexText, radix: 16);
            charCodes.add(charCode);
          }

          var decoded = codec.decode(charCodes);
          buffer.write(decoded);
        }
        i += 2;
      } else if (char == '_') {
        buffer.write(' ');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  void _writeQuotedPrintable(int rune, StringBuffer buffer, Codec codec) {
    var runeText = String.fromCharCode(rune);
    var encoded = codec.encode(runeText);
    for (var charCode in encoded) {
      var paddedHexValue = charCode.toRadixString(16).toUpperCase();
      buffer.write('=');
      if (paddedHexValue.length == 1) {
        buffer.write('0');
      }
      buffer.write(paddedHexValue);
    }
  }

  @override
  Uint8List decodeData(String part) {
    return null;
  }
}
