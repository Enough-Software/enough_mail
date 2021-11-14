import 'dart:convert';

/// Provides Modified UTF7 encoder and decoder.
/// Compare https://tools.ietf.org/html/rfc3501#section-5.1.3 and https://tools.ietf.org/html/rfc2152 for details.
/// Inspired by https://github.com/jstedfast/MailKit/blob/master/MailKit/Net/Imap/ImapEncoding.cs
class ModifiedUtf7Codec {
  /// Creates a new modified UTF7 codec
  const ModifiedUtf7Codec();

  static const String _utf7Alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+,';

  static const List<int> _utf7Rank = [
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    62,
    63,
    255,
    255,
    255,
    52,
    53,
    54,
    55,
    56,
    57,
    58,
    59,
    60,
    61,
    255,
    255,
    255,
    255,
    255,
    255,
    255,
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
    24,
    25,
    255,
    255,
    255,
    255,
    255,
    255,
    26,
    27,
    28,
    29,
    30,
    31,
    32,
    33,
    34,
    35,
    36,
    37,
    38,
    39,
    40,
    41,
    42,
    43,
    44,
    45,
    46,
    47,
    48,
    49,
    50,
    51,
    255,
    255,
    255,
    255,
    255,
  ];

  void _utf7ShiftOut(StringBuffer output, int u, int bits) {
    if (bits > 0) {
      final x = (u << (6 - bits)) & 0x3f;
      output.write(_utf7Alphabet[x]);
    }

    output.write('-');
  }

  /// Encodes the specified text in Modified UTF7 format.
  /// [text] specifies the text to be encoded.
  String encodeText(String text) {
    final encoded = StringBuffer();
    var shifted = false;
    var bits = 0, u = 0;

    for (var index = 0; index < text.length; index++) {
      final character = text[index];
      final codeUnit = character.codeUnitAt(0);
      if (codeUnit >= 0x20 && codeUnit < 0x7f) {
        // characters with octet values 0x20-0x25 and 0x27-0x7e
        // represent themselves while 0x26 ("&") is represented
        // by the two-octet sequence "&-"

        if (shifted) {
          _utf7ShiftOut(encoded, u, bits);
          shifted = false;
          bits = 0;
        }

        if (codeUnit == 0x26) {
          encoded.write('&-');
        } else {
          encoded.write(character);
        }
      } else {
        // base64 encode
        if (!shifted) {
          encoded.write('&');
          shifted = true;
        }

        u = (u << 16) | (codeUnit & 0xffff);
        bits += 16;

        while (bits >= 6) {
          final x = (u >> (bits - 6)) & 0x3f;
          encoded.write(_utf7Alphabet[x]);
          bits -= 6;
        }
      }
    }

    if (shifted) {
      _utf7ShiftOut(encoded, u, bits);
    }

    return encoded.toString();
  }

  /// Decodes the specified [text]
  ///
  /// [codec] the optional character encoding (charset, defaults to utf-8)
  String decodeText(String text, [Encoding codec = utf8]) {
    final decoded = StringBuffer();
    var shifted = false;
    var bits = 0, v = 0;
    var index = 0;
    String c;

    while (index < text.length) {
      c = text[index++];

      if (shifted) {
        final codeUnit = c.codeUnitAt(0);
        if (c == '-') {
          // shifted back out of modified UTF-7
          shifted = false;
          bits = v = 0;
        } else if (codeUnit > 127) {
          // invalid UTF-7
          return text;
        } else {
          final rank = _utf7Rank[codeUnit];

          if (rank == 0xff) {
            // invalid UTF-7
            return text;
          }

          v = (v << 6) | rank;
          bits += 6;

          if (bits >= 16) {
            final u = (v >> (bits - 16)) & 0xffff;
            decoded.write(String.fromCharCode(u));
            bits -= 16;
          }
        }
      } else if (c == '&' && index < text.length) {
        if (text[index] == '-') {
          decoded.write('&');
          index++;
        } else {
          // shifted into modified UTF-7
          shifted = true;
        }
      } else {
        decoded.write(c);
      }
    }

    return decoded.toString();
  }
}
