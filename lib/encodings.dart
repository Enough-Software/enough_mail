import 'dart:convert';

class EncodingsHelper {
  static const String utfEncodingStart = '=?utf-8?';
  static const String utf8base64StartSequence = '=?utf-8?B?';
  static const String utf8QencodingStartSequence = '=?utf-8?Q?';
  static const String encodingEndSequence = '?=';

  static String decodeAny(String input) {
    if (input == null) {
      return null;
    }
    var sequenceStart = input.indexOf(utfEncodingStart);
    if (sequenceStart != -1) {
      var startIndex = input.indexOf(utf8base64StartSequence, sequenceStart);
      if (startIndex != -1) {
        return _decode(
            input, utf8base64StartSequence, startIndex, decodeUtfBase64Part);
      } else {
        startIndex = input.indexOf(utf8QencodingStartSequence, sequenceStart);
        if (startIndex != -1) {
          return _decode(input, utf8QencodingStartSequence, startIndex,
              decodeQuotedPrintablePart);
        }
      }
    }
    return input;
  }

  static String decodeUtfBase64Part(String part) {
    var outputList = base64.decode(part);
    return String.fromCharCodes(outputList);
  }

  static String decodeQuotedPrintablePart(String part) {
    var buffer = StringBuffer();
    for (var i = 0; i < part.length; i++) {
      var char = part[i];
      if (char == '=') {
        var hexText = part.substring(i + 1, i + 3);
        var charCode = int.parse(hexText, radix: 16);
        buffer.writeCharCode(charCode);
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
      String Function(String) decodePart) {
    var endIndex =
        input.indexOf(encodingEndSequence, startIndex + startSequence.length);
    var buffer = StringBuffer();
    if (startIndex > 0) {
      buffer.write(input.substring(0, startIndex));
    }
    while (startIndex != -1 && endIndex != -1) {
      var part = input.substring(startIndex + startSequence.length, endIndex);
      buffer.write(decodePart(part));
      startIndex =
          input.indexOf(startSequence, endIndex + encodingEndSequence.length);
      if (startIndex > endIndex + encodingEndSequence.length) {
        buffer.write(
            input.substring(endIndex + encodingEndSequence.length, startIndex));
      } else if (startIndex == -1 &&
          endIndex + encodingEndSequence.length < input.length) {
        buffer.write(input.substring(endIndex + encodingEndSequence.length));
      }
      if (startIndex != -1) {
        endIndex = input.indexOf(
            encodingEndSequence, startIndex + startSequence.length);
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
