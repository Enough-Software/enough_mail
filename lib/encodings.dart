import 'dart:convert';

class EncodingsHelper {
  static const String _encodingEndSequence = '?=';
  static final RegExp _encodingExpression = RegExp(
      r'\=\?.+?\?.+?\?.+?\?\='); // the question marks after plus make this regular expression non-greedy
  static final Map<String, Encoding> _codecsByName = <String, Encoding>{
    'utf-8': utf8,
    'utf8': utf8,
    '8bit': utf8,
    '7bit': ascii,
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
      var part = sequence.substring(contentStartIndex, sequence.length - _encodingEndSequence.length);
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
      var tail = input.substring(endIndex);
      var tail2 = input.substring(endIndex + _encodingEndSequence.length);
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

  /// Encodes the given [dateTime] to a valid MIME date representation
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

  /// Decodes the given MIME [dateText] to a DateTime
  static DateTime decodeDate(String dateText) {
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
    if (dateText == null || dateText.isEmpty) {
      return null;
    }
    var original = dateText;
    var months = <String>[
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec'
    ];
    var splitIndex = dateText.indexOf(',');
    if (splitIndex != -1) {
      // remove weekday
      dateText = dateText.substring(splitIndex + 1).trim();
    }
    var spaceIndex = dateText.indexOf(' ');
    if (spaceIndex == -1) {
      return null;
    }
    var dayText = dateText.substring(0, spaceIndex);
    dateText = dateText.substring(spaceIndex + 1).trimLeft();
    spaceIndex = dateText.indexOf(' ');
    if (spaceIndex == -1) {
      return null;
    }
    var monthText = dateText.substring(0, spaceIndex);
    dateText = dateText.substring(spaceIndex + 1).trimLeft();
    spaceIndex = dateText.indexOf(' ');
    if (spaceIndex == -1) {
      return null;
    }
    var yearText = dateText.substring(0, spaceIndex);
    dateText = dateText.substring(spaceIndex + 1).trimLeft();
    spaceIndex = dateText.indexOf(' ');
    if (spaceIndex == -1) {
      return null;
    }
    var timeText = dateText.substring(0, spaceIndex);
    var zoneText = '+0000';
    if (dateText.length > spaceIndex) {
      dateText = dateText.substring(spaceIndex + 1).trim();
      zoneText = dateText;
    }
    var dayOfMonth = int.tryParse(dayText);
    if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
      print('Invalid day $dayText in date $original');
      return null;
    }
    var month = months.indexOf(monthText.toLowerCase()) + 1;
    if (month == 0) {
      print('Invalid month $monthText in date $original');
      return null;
    }
    var year = int.tryParse(yearText);
    if (year == null) {
      print('Invalid year $yearText in date $original');
      return null;
    }
    var timeParts = timeText.split(':');
    if (timeParts.length < 2) {
      print('Invalid time $timeText in date $original');
      return null;
    }
    var second = 0;
    var hour = int.tryParse(timeParts[0]);
    var minute = int.tryParse(timeParts[1]);
    if (timeParts.length > 2) {
      second = int.tryParse(timeParts[2]);
    }
    if (hour == null || minute == null || second == null) {
      print('Invalid time $timeText in date $original');
      return null;
    }
    if (zoneText.length != 5) {
      if (zoneText.length == 4 &&
          !(zoneText.startsWith('+') || zoneText.startsWith('-'))) {
        zoneText = '+' + zoneText;
      } else {
        print('invalid time zone $zoneText in $original');
        return null;
      }
    }
    var timeZoneHours = int.tryParse(zoneText.substring(1, 3));
    var timeZoneMinutes = int.tryParse(zoneText.substring(3));
    if (timeZoneHours == null || timeZoneMinutes == null) {
      print('invalid time zone $zoneText in $original');
      return null;
    }
    var dateTime = DateTime.utc(year, month, dayOfMonth, hour, minute, second);
    var isWesternTimeZone = zoneText.startsWith('+');
    var timeZoneDuration =
        Duration(hours: timeZoneHours, minutes: timeZoneMinutes);
    if (isWesternTimeZone) {
      dateTime = dateTime.add(timeZoneDuration);
    } else {
      dateTime = dateTime.subtract(timeZoneDuration);
    }
    return dateTime;
  }
}
