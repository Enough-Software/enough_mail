import 'dart:convert';
import 'dart:typed_data';
import 'package:enough_mail/mail_conventions.dart';

import 'mail_codec.dart';

/// Provides base64 encoder and decoder.
/// Compare https://tools.ietf.org/html/rfc2045#page-23 for details.
class Base64MailCodec extends MailCodec {
  const Base64MailCodec();

  /// Encodes the specified text in base64 format.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set [wrap] to false in case you do not want to wrap lines.
  @override
  String encodeText(String text, {Codec codec = utf8, bool wrap = true}) {
    var charCodes = codec.encode(text);
    return encodeData(charCodes);
  }

  /// Encodes the header text in base64 only if required.
  /// [text] specifies the text to be encoded.
  /// [codec] the optional codec, which defaults to utf8.
  /// Set the optional [fromStart] to true in case the encoding should  start at the beginning of the text and not in the middle.
  @override
  String encodeHeader(String text, {bool fromStart = false}) {
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
      if (startIndex > 0) {
        buffer.write(text.substring(0, startIndex));
      }
      buffer.write('=?utf8?B?');
      var textToEncode =
          fromStart ? text : text.substring(startIndex, endIndex + 1);
      var encoded = encodeText(textToEncode, wrap: false);
      buffer.write(encoded);
      buffer.write('?=');
      if (endIndex < text.length - 1) {
        buffer.write(text.substring(endIndex + 1));
      }
      return buffer.toString();
    }
  }

  @override
  Uint8List decodeData(String part) {
    part = part.replaceAll('\r\n', '');
    var numberOfRequiredPadding =
        part.length % 4 == 0 ? 0 : 4 - part.length % 4;
    while (numberOfRequiredPadding > 0) {
      part += '=';
      numberOfRequiredPadding--;
    }
    return base64.decode(part);
  }

  @override
  String decodeText(String part, Encoding codec) {
    var outputList = decodeData(part);
    return codec.decode(outputList);
  }

  /// Encodes the specified [data] in base64 format.
  /// Set [wrap] to false in case you do not want to wrap lines.
  String encodeData(List<int> data, {bool wrap = true}) {
    var base64Text = base64.encode(data);
    if (wrap) {
      base64Text = _wrapText(base64Text);
    }
    return base64Text;
  }

  String _wrapText(String text) {
    var chunkLength = MailConventions.textLineMaxLength;
    var length = text.length;
    if (length <= chunkLength) {
      return text;
    }
    var chunkIndex = 0;
    var buffer = StringBuffer();
    while (length > chunkLength) {
      var startPos = chunkIndex * chunkLength;
      var endPos = startPos + chunkLength;
      buffer.write(text.substring(startPos, endPos));
      buffer.write('\r\n');
      chunkIndex++;
      length -= chunkLength;
    }
    if (length > 0) {
      var startPos = chunkIndex * chunkLength;
      buffer.write(text.substring(startPos));
    }
    return buffer.toString();
  }
}
