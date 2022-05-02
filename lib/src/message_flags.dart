/// Contains common message flags
class MessageFlags {
  /// Do not allow instantiation
  MessageFlags._();

  /// The message has been read by the user
  static const String seen = r'\Seen';

  /// The message has been replied by the user
  static const String answered = r'\Answered';

  /// The message has been marked as important / favorite by the user
  static const String flagged = r'\Flagged';

  /// The message has been marked as deleted
  static const String deleted = r'\Deleted';

  /// The message is a draft and not yet complete.
  static const String draft = r'\Draft';

  /// The message has been forwarded
  ///
  ///  - note this is a common but not standardized keyword.
  static const String keywordForwarded = r'$Forwarded';

  /// For this message a read notification has been sent
  ///
  ///  - note this is a common but not standardized keyword.
  static const String keywordMdnSent = r'$MDNSent';

  /// Marks this message as being recent.
  ///
  /// This flag cannot be changed or set by clients.
  static const String recent = r'\Recent';
}
