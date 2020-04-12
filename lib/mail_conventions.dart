/// Contains various mail specific conventions
class MailConventions {
  /// The maximum length of a text email should not be longer than 76 characters.
  static const int textLineMaxLength = 76;

  /// Common abbreviations in subject header for replied messages, compare https://en.wikipedia.org/wiki/List_of_email_subject_abbreviations
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

  /// Common abbreviations in subject header for forwarded messages, compare https://en.wikipedia.org/wiki/List_of_email_subject_abbreviations
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

  static const String headerTo = 'To';
  static const String headerCc = 'Cc';
  static const String headerBcc = 'Bcc';
  static const String headerDate = 'Date';
  static const String headerSubject = 'Subject';
  static const String headerMessageId = 'Message-Id';
  static const String headerReferences = 'References';
  static const String headerInReplyTo = 'In-Reply-To';
  static const String headerFrom = 'From';
  static const String headerSender = 'Sender';
  static const String headerContentType = 'Content-Type';
  static const String headerContentTransferEncoding =
      'Content-Transfer-Encoding';
  static const String headerContentDisposition = 'Content-Disposition';
  static const String headerContentDescription = 'Content-Description';
//static const String header = '';

}
