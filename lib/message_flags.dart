/// Contains common message flags
class MessageFlags {
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

  /// The message has been forwarded - note this is a common but not standardized keyword.
  static const String keywordForwarded = r'$Forwarded';
}
