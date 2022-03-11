/// Contains various mail specific conventions
class MailConventions {
  /// The maximum length of a text email should not be longer
  /// than 76 characters.
  static const int textLineMaxLength = 76;

  /// The maximum length of an encoded word in header space should not be longer
  /// than 75 characters.
  ///
  /// That includes the charset, encoding, delimiters and actual data,
  /// compare https://tools.ietf.org/html/rfc2047#section-2
  static const int encodedWordMaxLength = 75;

  /// The maximum length of a line in an Internet Message Format,
  /// compare https://tools.ietf.org/html/rfc5322#section-2.1.1
  static const int messageLineMaxLength = 998;

  /// Default English reply abbreviation `'Re'`
  static const String defaultReplyAbbreviation = 'Re';

  /// Default English reply header template `'On <date> <from> wrote:'`
  static const String defaultReplyHeaderTemplate = 'On <date> <from> wrote:';

  /// Default English forward abbreviation `'Fwd'`
  static const String defaultForwardAbbreviation = 'Fwd';

  /// Default English forward header template
  static const String defaultForwardHeaderTemplate =
      '---------- Original Message ----------\r\n'
      'From: <from>\r\n'
      '[[to To: <to>\r\n]]'
      '[[cc CC: <cc>\r\n]]'
      'Date: <date>\r\n'
      '[[subject Subject: <subject>\r\n]]';

  /// Standard template for message disposition notification messages
  /// aka read receipts.
  ///
  /// When you want to use your own template you can use the fields
  /// `<subject>`, `<date>`, `<recipient>` and `<sender>`.
  static const String defaultReadReceiptTemplate =
      '''The message sent on <date> to <recipient> with '
      'subject "<subject>" has been displayed.\r
This is no guarantee that the message has been read or understood.''';

  // cSpell:disable

  /// Common abbreviations in subject header for replied messages,
  /// compare https://en.wikipedia.org/wiki/List_of_email_subject_abbreviations
  static const List<String> subjectReplyAbbreviations = <String>[
    'Re', // English
    'RE', // English, Spanish, fr-CA
    'رد', // Arabic
    '回复', // Simplified Chinese
    '回覆', // Traditional Chinese
    'SV', // Danish + Icelandic + Norwegian + Swedish
    'Antw', // Dutch
    'VS', // Finish
    'REF', // French (also RE)
    'AW', // German
    'ΑΠ', // Greek
    'ΣΧΕΤ', // Greek
    'השב', // Hebrew
    'Vá', // Hungarian
    'R', // Italian
    'RIF', // Italian
    'BLS', // Indonesian
    'RES', // Portuguese
    'Odp', // Polnish
    'YNT', // Turkish
    'ATB' // Welsh
  ];

  /// Common abbreviations in subject header for forwarded messages,
  /// compare https://en.wikipedia.org/wiki/List_of_email_subject_abbreviations
  static const List<String> subjectForwardAbbreviations = <String>[
    'Fwd',
    'FWD',
    'Fw',
    'FW',
    'إعادة توجيه', // Arabic
    '转发', // Simplified Chinese
    '轉寄', // Traditional Chinese
    'VS', // Danish + Norwegian + Swedish
    'Doorst', // Dutch
    'VL', // Finish
    'TR', // French
    'WG', // German
    'ΠΡΘ', // Greek
    'הועבר', // Hebrew
    'Továbbítás', // Hungarian
    'I', // Italian
    'FS', // Icelandic
    'TRS', // Indonesian
    'VB', // Swedish
    'RV', // Spanish
    'ENC', // Portuguese
    'PD', // Polnish
    'İLT', // Turkish
    'YML' // Welsh
  ];
  // cSpell:enable

  /// The `To` recipients header
  static const String headerTo = 'To';

  /// The `CC` CarbonCopy recipients header
  static const String headerCc = 'Cc';

  /// The `BCC` BlindCarbonCopy recipients header
  static const String headerBcc = 'Bcc';

  /// The `Date` header
  static const String headerDate = 'Date';

  /// The `Subject` header
  static const String headerSubject = 'Subject';

  /// The `Message-Id` header
  static const String headerMessageId = 'Message-Id';

  /// The `References` header
  static const String headerReferences = 'References';

  /// The `In-Reply-To` header
  static const String headerInReplyTo = 'In-Reply-To';

  /// The `From` header
  static const String headerFrom = 'From';

  /// The `Sender` header
  static const String headerSender = 'Sender';

  /// The `Content-Type` header
  static const String headerContentType = 'Content-Type';

  /// The `Content-Transfer-Encoding` header
  static const String headerContentTransferEncoding =
      'Content-Transfer-Encoding';

  /// The `Content-Disposition` header
  static const String headerContentDisposition = 'Content-Disposition';

  /// The `Content-Description` header
  static const String headerContentDescription = 'Content-Description';

  /// The `MIME-Version` header
  static const String headerMimeVersion = 'MIME-Version';

  /// The `Disposition-Notification-To` header
  static const String headerDispositionNotificationTo =
      'Disposition-Notification-To';

  /// The `Disposition-Notification-Options` header
  static const String headerDispositionNotificationOptions =
      'Disposition-Notification-Options';

  /// The `Return-Path` header
  static const String headerReturnPath = 'Return-Path';
//static const String header = '';

}
