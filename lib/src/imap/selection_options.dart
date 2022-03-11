/// LIST-EXTENDED selection options
enum SelectionOptions {
  /// Includes flags for special-use mailboxes,
  /// such as those used to hold draft messages or sent messages.
  specialUse,

  /// List only subscribed names.
  /// Supplements the `LSUB` command with accurate and complete information.
  subscribed,

  /// Shows also remote mailboxes, marked with "\Remote" attribute.
  remote,

  /// Forces the return of information about non matched mailboxes
  /// whose children matches the selection options.
  ///
  /// Cannot be uses alone or in combination with only the REMOTE option
  recursiveMatch,
}

/// Extension on [SelectionOptions]
extension Stringify on SelectionOptions {
  /// The value as text
  String value() {
    switch (this) {
      case SelectionOptions.specialUse:
        return 'SPECIAL-USE';
      case SelectionOptions.subscribed:
        return 'SUBSCRIBED';
      case SelectionOptions.remote:
        return 'REMOTE';
      case SelectionOptions.recursiveMatch:
        return 'RECURSIVEMATCH';
    }
  }
}
