/// Encodes and decodes dates according to MIME requirements.
class DateCodec {
  // do not allow instantiation
  DateCodec._();

  static const _weekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun'
  ];
  static const _months = <String>[
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
  static const _monthsByName = <String, int>{
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  // cSpell:disable
  // source: https://en.wikipedia.org/wiki/List_of_time_zone_abbreviations
  static const _timeZonesByName = <String, String>{
    'GMT': '+0000', // Greenwich Mean Time - most often this will be used
    // by non-compliant implementations
    'Z': '+0000', // Zulu time zone - artificial timezone, equivalent to UTC
    'ACDT': '+1030', // Australian Central Daylight Savings Time
    'ACST': '+0930', // Australian Central Standard Time
    'ACT': '-0500', // Acre Time
    'ACWST': '+0845', // Australian Central Western Standard Time (unofficial)
    'ADT': '-0300', // Atlantic Daylight Time
    'AEDT': '+1100', // 	Australian Eastern Daylight Savings Time
    'AEST': '+1000', // Australian Eastern Standard Time
    'AET': '+1000', // 	Australian Eastern Time - can also apparently be +1100
    'AFT': '+0430', // Afghanistan Time
    'AKDT': '-0800', // Alaska Daylight Time
    'AKST': '-0900', // 	Alaska Standard Time
    'ALMT': '+0600', // Alma-Ata Time
    'AMST': '-0300', // Amazon Summer Time (Brazil)
    'AMT': '+0400', // can be Amazon Time or Armenia Time. Since Brasil
    // has other time zones we assume Armenia Time
    'ANAT': '+1200', // Anadyr Time
    'AQTT': '+0500', // Aqtobe Time
    'ART': '-0300', // Argentina Time
    'AST':
        '+0300', // Arabia Standard Time, could also be Atlantic Standard Time
    'AWST': '+0800', // Australian Western Standard Time
    'AZOST': '+0000', // Azores Summer Time
    'AZOT': '+0100', // Azores Standard Time
    'AZT': '+0400', // Azerbaijan Time
    'BDT': '+0800', // Brunei Time
    'BIOT': '+0600', // British Indian Ocean Time
    'BIT': '-1200', // Baker Island Time
    'BOT': '-0400', // Bolivia Time
    'BRST': '-0200', // Brasília Summer Time
    'BRT': '-0300', // Brasília Time
    'BST': '+0600', // Bangladesh Standard Time,
    // but could also be Bougainville Standard Time +1100
    'BTT': '+0600', // 	Bhutan Time
    'CAT': '+0200', // Central Africa Time
    'CCT': '+0630', // Cocos Islands Time
    'CDT': '-0500', // Central Daylight Time (North America)
    // - could also be Cuba Daylight Time -0400
    'CEST': '+0200', // Central European Summer Time (Cf. HAEC)
    'CET': '+0100', // Central European Time
    'CHADT': '+1345', // Chatham Daylight Time
    'CHAST': '+1245', // Chatham Standard Time
    'CHOT': '+0800', // Choibalsan Standard Time
    'CHOST': '+0900', // Choibalsan Summer Time
    'CHST': '+1000', // Chuuk Time
    'CIST': '-0800', // Clipperton Island Standard Time
    'CIT': '+0800', // Central Indonesia Time
    'CKT': '-1000', // Cook Island Time
    'CLST': '-0300', // Chile Summer Time
    'CLT': '-0400', // Chile Standard Time
    'COST': '-0400', // Colombia Summer Time
    'COT': '-0500', // Colombia Time
    'CST': '-0600', // Central Standard Time (North America),
    // could also be China Standard Time +0800 or Cuba Standard Time -0500
    'CT': '+0800', // China Time
    'CVT': '-0100', // Cape Verde Time
    'CWST': '+0845', // Central Western Standard Time (Australia) unofficial
    'CXT': '+0700', // Christmas Island Time
    'DAVT': '+0700', // Davis Time
    'DDUT': '+1000', // Dumont d'Urville Time
    'DFT': '+0100', // AIX-specific equivalent of Central European Time
    'EASST': '-0500', // Easter Island Summer Time
    'EAST': '-0600', // Easter Island Standard Time
    'EAT': '+0300', // East Africa Time
    'ECT': '-0500', //  Ecuador Time, could also be Eastern Caribbean Time -0400
    'EDT': '-0400', // 	Eastern Daylight Time (North America)
    'EEST': '+0300', // 	Eastern European Summer Time
    'EET': '+0200', // Eastern European Time
    'EGST': '+0000', // Eastern Greenland Summer Time
    'EGT': '-0100', // Eastern Greenland Time
    'EIT': '+0900', // Eastern Indonesian Time
    'EST': '-0500', // Eastern Standard Time (North America)
    'FET': '+0300', // Further-eastern European Time
    'FJT': '+1200', // Fiji Time
    'FKST': '-0300', // Falkland Islands Summer Time
    'FKT': '-0400', // 	Falkland Islands Time
    'FNT': '-0200', // Fernando de Noronha Time
    'GALT': '-0600', // Galápagos Time
    'GAMT': '-0900', // Gambier Islands Time
    'GET': '+0400', // 	Georgia Standard Time
    'GFT': '-0300', // French Guiana Time
    'GILT': '+1200', // Gilbert Island Time
    'GIT': '-0900', // Gambier Island Time
    'GST': '+0400', // Gulf Standard Time,
    // could also be South Georgia and the South Sandwich Islands Time -0200
    'GYT': '-0400', // Guyana Time
    'HDT': '-0900', // Hawaii–Aleutian Daylight Time
    'HAEC': '+0200', // Heure Avancée d'Europe Centrale
    // French-language name for CEST
    'HST': '-1000', // 	Hawaii–Aleutian Standard Time
    'HKT': '+0800', // Hong Kong Time
    'HMT': '+0500', // Heard and McDonald Islands Time
    'HOVST': '+0800', // Hovd Summer Time
    'HOVT': '+0700', // Hovd Time
    'ICT': '+0700', // Indochina Time
    'IDLW': '-1200', // International Day Line West time zone
    'IDT': '+0300', // Israel Daylight Time
    'IOT': '+0300', // Indian Ocean Time
    'IRDT': '+0430', // Iran Daylight Time
    'IRKT': '+0800', // Irkutsk Time
    'IRST': '+0330', // Iran Standard Time
    'IST': '+0530', // 	Indian Standard Time, could also be Irish Standard Time
    // +0100 or Israel Standard Time +0200
    'JST': '+0900', // Japan Standard Time
    'KALT': '+0200', // Kaliningrad Time
    'KGT': '+0600', // Kyrgyzstan Time
    'KOST': '+1100', // Kosrae Time
    'KRAT': '+0700', // Krasnoyarsk Time
    'KST': '+0900', // Korea Standard Time
    'LHST': '+1030', // Lord Howe Standard Time,
    // could also be Lord Howe Summer Time +1100
    'LINT': '+1400', // Line Islands Time
    'MAGT': '+1200', // Magadan Time
    'MART': '-0930', // Marquesas Islands Time
    'MAWT': '+0500', // Mawson Station Time
    'MDT': '-0600', // Mountain Daylight Time (North America)
    'MET': '+0100', // Middle European Time Same zone as CET
    'MEST': '+0200', // Middle European Summer Time Same zone as CEST
    'MHT': '+1200', // Marshall Islands Time
    'MIST': '+1100', // Macquarie Island Station Time
    'MIT': '-0930', // 	Marquesas Islands Time
    'MMT': '+0630', // Myanmar Standard Time
    'MSK': '+0300', // 	Moscow Time
    'MST': '-0700', // Mountain Standard Time (North America),
    // could also be Malaysia Standard Time +0800
    'MUT': '+0400', // Mauritius Time
    'MVT': '+0500', // Maldives Time
    'MYT': '+0800', // Malaysia Time
    'NCT': '+1100', // New Caledonia Time
    'NDT': '-0230', // Newfoundland Daylight Time
    'NFT': '+1100', // Norfolk Island Time
    'NOVT': '+0700', // Novosibirsk Time
    'NPT': '+0545', // Nepal Time
    'NST': '-0330', // 	Newfoundland Standard Time
    'NT': '-0330', // Newfoundland Time
    'NUT': '-1100', // Niue Time
    'NZDT': '+1300', // New Zealand Daylight Time
    'NZST': '+1200', // New Zealand Standard Time
    'OMST': '+0600', // Omsk Time
    'ORAT': '+0500', // Oral Time
    'PDT': '-0700', // 	Pacific Daylight Time (North America)
    'PET': '-0500', // Peru Time
    'PETT': '+1200', // Kamchatka Time
    'PGT': '+1000', // Papua New Guinea Time
    'PHOT': '+1300', // Phoenix Island Time
    'PHT': '+0800', // Philippine Time
    'PKT': '+0500', // 	Pakistan Standard Time
    'PMDT': '-0200', // Saint Pierre and Miquelon Daylight Time
    'PMST': '-0300', // 	Saint Pierre and Miquelon Standard Time
    'PONT': '+1100', // Pohnpei Standard Time
    'PST': '-0800', // Pacific Standard Time (North America),
    // could also be Philippine Standard Time +0800
    'PYST': '-0300', // Paraguay Summer Time
    'PYT': '-0400', // Paraguay Time
    'RET': '+0400', // Réunion Time
    'ROTT': '-0300', // Rothera Research Station Time
    'SAKT': '+1100', // 	Sakhalin Island Time
    'SAMT': '+0400', // Samara Time
    'SAST': '+0200', // South African Standard Time
    'SBT': '+1100', // Solomon Islands Time
    'SCT': '+0400', // Seychelles Time
    'SDT': '-1000', // Samoa Daylight Time
    'SGT': '+0800', // Singapore Time
    'SLST': '+0530', // Sri Lanka Standard Time
    'SRET': '+1100', // Srednekolymsk Time
    'SRT': '-0300', // Suriname Time
    'SST': '+0800', // Singapore Standard Time,
    // could also be Samoa Standard Time (-1100)
    'SYOT': '+0300', // Showa Station Time
    'TAHT': '-1000', // Tahiti Time
    'THA': '+0700', // Thailand Standard Time
    'TFT': '+0500', // French Southern and Antarctic Time
    'TJT': '+0500', // Tajikistan Time
    'TKT': '+1300', // Tokelau Time
    'TLT': '+0900', // Timor Leste Time
    'TMT': '+0500', // Turkmenistan Time
    'TRT': '+0300', // Turkey Time
    'TOT': '+1300', // Tonga Time
    'TVT': '+1200', // Tuvalu Time
    'ULAST': '+0900', // 	Ulaanbaatar Summer Time
    'ULAT': '+0800', // Ulaanbaatar Standard Time
    'UTC': '+0000', // 	Coordinated Universal Time
    'UYST': '-0200', // Uruguay Summer Time
    'UYT': '-0300', // Uruguay Standard Time
    'UZT': '+0500', // Uzbekistan Time
    'VET': '-0400', // Venezuelan Standard Time
    'VLAT': '+1000', // Vladivostok Time
    'VOLT': '+0400', // Volgograd Time
    'VOST': '+0600', // Vostok Station Time
    'VUT': '+1100', // 	Vanuatu Time
    'WAKT': '+1200', // Wake Island Time
    'WAST': '+0200', // West Africa Summer Time
    'WAT': '+0100', // West Africa Time
    'WEST': '+0100', // Western European Summer Time
    'WET': '+0000', // Western European Time
    'WIT': '+0700', // Western Indonesian Time
    'WGST': '-0200', // West Greenland Summer Time
    'WGT': '-0300', // West Greenland Time
    'WST': '+0800', // Western Standard Time (North America)
    'YAKT': '+0900', // Yakutsk Time
    'YEKT': '+0500', // Yekaterinburg Time
  };

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
    final buffer = StringBuffer()
      ..write(_weekdays[dateTime.weekday - 1])
      ..write(', ')
      ..write(dateTime.day.toString().padLeft(2, '0'))
      ..write(' ')
      ..write(_months[dateTime.month - 1])
      ..write(' ')
      ..write(dateTime.year)
      ..write(' ')
      ..write(dateTime.hour.toString().padLeft(2, '0'))
      ..write(':')
      ..write(dateTime.minute.toString().padLeft(2, '0'))
      ..write(':')
      ..write(dateTime.second.toString().padLeft(2, '0'))
      ..write(' ');
    if (dateTime.timeZoneOffset.inMinutes > 0) {
      buffer.write('+');
    } else {
      buffer.write('-');
    }
    final hours = dateTime.timeZoneOffset.inHours;
    if (hours < 10 && hours > -10) {
      buffer.write('0');
    }
    buffer.write(hours.abs());
    final minutes = dateTime.timeZoneOffset.inMinutes -
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

  /// Encodes only day-month-year of the given dateTime, e.g. `"1-MAR-2021"`
  static String encodeSearchDate(DateTime dateTime) {
    final buffer = StringBuffer()
      ..write('"')
      ..write(dateTime.day)
      ..write('-')
      ..write(_months[dateTime.month - 1])
      ..write('-')
      ..write(dateTime.year)
      ..write('"');
    return buffer.toString();
  }

  /// Decodes the given MIME [dateText] to the local DateTime
  static DateTime? decodeDate(final String? dateText) {
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
    var reminder = dateText;
    final splitIndex = reminder.indexOf(',');
    if (splitIndex != -1) {
      // remove weekday
      reminder = reminder.substring(splitIndex + 1).trim();
    }
    var spaceIndex = reminder.indexOf(' ');
    if (spaceIndex == -1) {
      return null;
    }
    final dayText = reminder.substring(0, spaceIndex);
    reminder = reminder.substring(spaceIndex + 1).trimLeft();
    spaceIndex = reminder.indexOf(' ');
    if (spaceIndex == -1) {
      return null;
    }
    final monthText = reminder.substring(0, spaceIndex);
    reminder = reminder.substring(spaceIndex + 1).trimLeft();
    spaceIndex = reminder.indexOf(' ');
    // ignore: invariant_booleans
    if (spaceIndex == -1) {
      return null;
    }
    final yearText = reminder.substring(0, spaceIndex);
    reminder = reminder.substring(spaceIndex + 1).trimLeft();
    spaceIndex = reminder.indexOf(' ');
    var timeText = reminder;
    var zoneText = '+0000';
    if (spaceIndex != -1) {
      timeText = reminder.substring(0, spaceIndex);
      if (reminder.length > spaceIndex) {
        reminder = reminder.substring(spaceIndex + 1).trim();
        spaceIndex = reminder.indexOf(' ');
        if (spaceIndex == -1) {
          zoneText = reminder;
        } else {
          zoneText = reminder.substring(0, spaceIndex);
        }
      }
    }
    final dayOfMonth = int.tryParse(dayText);
    if (dayOfMonth == null || dayOfMonth < 1 || dayOfMonth > 31) {
      print('Invalid day $dayText in date $dateText');
      return null;
    }
    final month = _monthsByName[monthText.toLowerCase()];
    if (month == null) {
      print('Invalid month $monthText in date $dateText');
      return null;
    }
    final year = int.tryParse(yearText.length == 2 ? '20$yearText' : yearText);
    if (year == null) {
      print('Invalid year $yearText in date $dateText');
      return null;
    }
    final timeParts = timeText.split(':');
    if (timeParts.length < 2) {
      print('Invalid time $timeText in date $dateText');
      return null;
    }
    int? second = 0;
    final hour = int.tryParse(timeParts[0]);
    final minute = int.tryParse(timeParts[1]);
    if (timeParts.length > 2) {
      second = int.tryParse(timeParts[2]);
    }
    if (hour == null || minute == null || second == null) {
      print('Invalid time $timeText in date $dateText');
      return null;
    }
    if (zoneText.length != 5) {
      if (zoneText.length == 4 &&
          !(zoneText.startsWith('+') || zoneText.startsWith('-'))) {
        zoneText = '+$zoneText';
      } else {
        // source: https://en.wikipedia.org/wiki/List_of_time_zone_abbreviations
        final zoneOffset = _timeZonesByName[zoneText];
        if (zoneOffset == null) {
          print('warning: invalid time zone [$zoneText] in $dateText');
        }
        zoneText = zoneOffset ?? '+0000';
      }
    }
    final timeZoneHours = int.tryParse(zoneText.substring(1, 3));
    final timeZoneMinutes = int.tryParse(zoneText.substring(3));
    if (timeZoneHours == null || timeZoneMinutes == null) {
      print('invalid time zone $zoneText in $dateText');
      return null;
    }
    var dateTime = DateTime.utc(year, month, dayOfMonth, hour, minute, second);
    final isWesternTimeZone = zoneText.startsWith('+');
    final timeZoneDuration =
        Duration(hours: timeZoneHours, minutes: timeZoneMinutes);
    if (isWesternTimeZone) {
      dateTime = dateTime.subtract(timeZoneDuration);
    } else {
      dateTime = dateTime.add(timeZoneDuration);
    }
    return dateTime.toLocal();
  }
  // cSpell:enable

}
