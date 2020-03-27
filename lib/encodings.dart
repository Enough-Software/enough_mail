import 'dart:convert';

/// Encodes and decodes base-64 and quoted printable encoded texts
class EncodingsHelper {
  static const String _encodingEndSequence = '?=';
  static final RegExp _encodingExpression = RegExp(
      r'\=\?.+?\?.+?\?.+?\?\='); // the question marks after plus make this regular expression non-greedy
  static final Map<String, Encoding> _codecsByName = <String, Encoding>{
    'utf-8': utf8,
    'utf8': utf8,
    'iso-8859-1': latin1,
    'latin-1': latin1,
    'iso-8859-2': utf8,
    'us-ascii': ascii,
    'ascii': ascii
  };
  static final Map<String, String Function(String, Encoding)> _decodersByName =
      <String, String Function(String, Encoding)>{
    'q': decodeQuotedPrintable,
    'quoted-printable': decodeQuotedPrintable,
    'b': decodeBase64,
    'base64': decodeBase64,
    'base-64': decodeBase64,
    '7bit': decodeOnlyCodec,
    '8bit': decodeOnlyCodec,
    'none': decodeOnlyCodec
  };

  static String decodeAny(String input) {
    if (input == null || input.isEmpty) {
      return input;
    }
    var buffer = StringBuffer();
    _decodeAnyImpl(input, buffer);
    return buffer.toString();
  }

  static void _decodeAnyImpl(String input, StringBuffer buffer) {
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
      var decoder = _decodersByName[decoderName];
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
      var decoded = decoder(part, codec);
      buffer.write(decoded);
      input = input.substring(match.end);
    }
    buffer.write(input);
  }

  static String decodeText(
      String text, String transferEncoding, String characterEncoding) {
    transferEncoding ??= 'none';
    characterEncoding ??= 'utf8';
    var codec = _codecsByName[characterEncoding.toLowerCase()];
    var decoder = _decodersByName[transferEncoding.toLowerCase()];
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

  static String decodeBase64(String part, Encoding codec) {
    part = part.replaceAll('\r\n', '');
    var numberOfRequiredPadding =
        part.length % 4 == 0 ? 0 : 4 - part.length % 4;
    while (numberOfRequiredPadding > 0) {
      part += '=';
      numberOfRequiredPadding--;
    }
    var outputList = base64.decode(part);
    return codec.decode(outputList);
  }

  static String decodeOnlyCodec(String part, Encoding codec) {
    //TODO does decoding code units even make sense??
    return codec.decode(part.codeUnits);
  }

  static String decodeQuotedPrintable(String part, Encoding codec) {
    var buffer = StringBuffer();
    for (var i = 0; i < part.length; i++) {
      var char = part[i];
      if (char == '=') {
        var hexText = part.substring(i + 1, i + 3);
        var charCode = int.parse(hexText, radix: 16);
        var charCodes = [charCode];
        while (part.length > (i + 4) && part[i + 3] == '=') {
          i += 3;
          var hexText = part.substring(i + 1, i + 3);
          charCode = int.parse(hexText, radix: 16);
          charCodes.add(charCode);
        }
        var decoded = codec.decode(charCodes);
        buffer.write(decoded);
        i += 2;
      } else if (char == '_') {
        buffer.write(' ');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }
}
