import 'dart:convert';

class EncodingsHelper {
  static const String _encodingEndSequence = '?=';
  static final RegExp _encodingExpression = RegExp(r'\=\?.+\?.+\?.+\?\=');
  static final RegExp _newLineExpression = RegExp(r'[\n\r]+(.*)');
  static final Map<String, Encoding> _codecsByName = <String, Encoding>{
    'utf-8': utf8,
    'utf8': utf8,
    '8bit': utf8,
    '7bit': ascii,
    'iso-8859-1': latin1,
    'latin-1': latin1
  };
  static final Map<String, String Function(String, Encoding)> _decodersByName =
      <String, String Function(String, Encoding)>{
    'q': decodeQuotedPrintable,
    'quoted-printable': decodeQuotedPrintable,
    'b': decodeBase64,
    'base64': decodeBase64,
    'base-64': decodeBase64,
    'none': decodeOnlyCodec
  };

  static String decodeAny(String input) {
    if (input == null || input.isEmpty) {
      return input;
    }
    var match = _encodingExpression.firstMatch(input);
    if (match == null) {
      return input;
    }
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
      return input;
    }
    var decoder = _decodersByName[decoderName];
    if (decoder == null) {
      print('Error: no decoder found for [$decoderName].');
      return input;
    }
    var startSequence = sequence.substring(0, separatorIndex + 3);
    return _decode(input, startSequence, match.start, decoder, codec);
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
        // check for soft line break
        var newLineMatch = _newLineExpression.firstMatch(hexText);
        if (newLineMatch != null) {
          buffer.write(newLineMatch.group(1));
        } else {
          // encoded character
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

  static String _decode(String input, String startSequence, int startIndex,
      String Function(String, Encoding) decoder, Encoding encoding) {
    var endIndex =
        input.indexOf(_encodingEndSequence, startIndex + startSequence.length);
    var buffer = StringBuffer();
    if (startIndex > 0) {
      buffer.write(input.substring(0, startIndex));
    }
    while (startIndex != -1 && endIndex != -1) {
      var part = input.substring(startIndex + startSequence.length, endIndex);
      buffer.write(decoder(part, encoding));
      startIndex =
          input.indexOf(startSequence, endIndex + _encodingEndSequence.length);
      if (startIndex > endIndex + _encodingEndSequence.length) {
        buffer.write(input.substring(
            endIndex + _encodingEndSequence.length, startIndex));
      } else if (startIndex == -1 &&
          endIndex + _encodingEndSequence.length < input.length) {
        buffer.write(input.substring(endIndex + _encodingEndSequence.length));
      }
      if (startIndex != -1) {
        endIndex = input.indexOf(
            _encodingEndSequence, startIndex + startSequence.length);
      }
    }
    return buffer.toString();
  }

  static String encodeDate(DateTime dateTime) {
    /*
Date and time values occur in several header fields.  This section
   specifies the syntax for a full date and time specification.  Though
   folding white space is permitted throughout the date-time
   specification, it is RECOMMENDED that a single space be used in each
   place that FWS appears (whether it is required or optional); some
   older implementations will not interpret longer sequences of folding
   white space correctly.
   date-time       =   [ day-of-week "," ] date time [CFWS]

   day-of-week     =   ([FWS] day-name) / obs-day-of-week

   day-name        =   "Mon" / "Tue" / "Wed" / "Thu" /
                       "Fri" / "Sat" / "Sun"

   date            =   day month year

   day             =   ([FWS] 1*2DIGIT FWS) / obs-day

   month           =   "Jan" / "Feb" / "Mar" / "Apr" /
                       "May" / "Jun" / "Jul" / "Aug" /
                       "Sep" / "Oct" / "Nov" / "Dec"

   year            =   (FWS 4*DIGIT FWS) / obs-year

   time            =   time-of-day zone

   time-of-day     =   hour ":" minute [ ":" second ]

   hour            =   2DIGIT / obs-hour

   minute          =   2DIGIT / obs-minute

   second          =   2DIGIT / obs-second

   zone            =   (FWS ( "+" / "-" ) 4DIGIT) / obs-zone

   The day is the numeric day of the month.  The year is any numeric
   year 1900 or later.

   The time-of-day specifies the number of hours, minutes, and
   optionally seconds since midnight of the date indicated.

   The date and time-of-day SHOULD express local time.

   The zone specifies the offset from Coordinated Universal Time (UTC,
   formerly referred to as "Greenwich Mean Time") that the date and
   time-of-day represent.  The "+" or "-" indicates whether the time-of-
   day is ahead of (i.e., east of) or behind (i.e., west of) Universal
   Time.  The first two digits indicate the number of hours difference
   from Universal Time, and the last two digits indicate the number of
   additional minutes difference from Universal Time.  (Hence, +hhmm
   means +(hh * 60 + mm) minutes, and -hhmm means -(hh * 60 + mm)
   minutes).  The form "+0000" SHOULD be used to indicate a time zone at
   Universal Time.  Though "-0000" also indicates Universal Time, it is
   used to indicate that the time was generated on a system that may be
   in a local time zone other than Universal Time and that the date-time
   contains no information about the local time zone.

   A date-time specification MUST be semantically valid.  That is, the
   day-of-week (if included) MUST be the day implied by the date, the
   numeric day-of-month MUST be between 1 and the number of days allowed
   for the specified month (in the specified year), the time-of-day MUST
   be in the range 00:00:00 through 23:59:60 (the number of seconds
   allowing for a leap second; see [RFC1305]), and the last two digits
   of the zone MUST be within the range 00 through 59.
   */
    var weekdays = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    var months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    var buffer = StringBuffer();
    buffer.write(weekdays[dateTime.weekday - 1]);
    buffer.write(', ');
    buffer.write(dateTime.day);
    buffer.write(' ');
    buffer.write(months[dateTime.month - 1]);
    buffer.write(' ');
    buffer.write(dateTime.year);
    buffer.write(' ');
    buffer.write(dateTime.hour);
    buffer.write(':');
    buffer.write(dateTime.minute);
    buffer.write(':');
    buffer.write(dateTime.second);
    buffer.write(' ');
    if (dateTime.timeZoneOffset.inMinutes > 0) {
      buffer.write('+');
    } else {
      buffer.write('-');
    }
    var hours = dateTime.timeZoneOffset.inHours;
    if (hours < 10 && hours > -10) {
      buffer.write('0');
    }
    buffer.write(hours);
    var minutes = dateTime.timeZoneOffset.inMinutes -
        (dateTime.timeZoneOffset.inHours * 60);
    if (minutes == 0) {
      buffer.write('00');
    } else {
      if (minutes < 10 && minutes > -10) {
        buffer.write('0');
      }
      buffer.write(minutes);
    }
    return buffer.toString();
  }
}
