import 'package:enough_mail/codecs/modified_utf7_codec.dart';

/// Contains common flags for mailboxes
enum MailboxFlag {
  marked,
  unMarked,
  hasChildren,
  hasNoChildren,
  noSelect,
  select,
  noInferior,
  subscribed,
  remote,
  nonExistent,
  all,
  inbox,
  sent,
  drafts,
  junk,
  trash,
  archive,
  flagged
}

/// Stores meta data about a folder aka Mailbox
class Mailbox {
  static const ModifiedUtf7Codec _modifiedUtf7Codec = ModifiedUtf7Codec();
  String get encodedName => _modifiedUtf7Codec.encodeText(_name);
  String _name;
  String get name => _name;
  set name(String value) => _name = _modifiedUtf7Codec.decodeText(value);

  String get encodedPath => _modifiedUtf7Codec.encodeText(_path);
  String _path;
  String get path => _path;
  set path(String value) => _path = _modifiedUtf7Codec.decodeText(value);
  bool isMarked = false;
  bool hasChildren = false;
  bool isSelected = false;
  bool isUnselectable = false;
  int messagesRecent;
  int messagesExists;

  /// The number of unseen messages - only reported through STATUS calls
  int messagesUnseen;
  int firstUnseenMessageSequenceId;
  int uidValidity;
  int uidNext;
  bool isReadWrite = false;

  /// The last modification sequence in case the server supports the CONDSTORE or QRESYNC capability. Useful for message synchronization.
  int highestModSequence;
  List<MailboxFlag> flags = <MailboxFlag>[];
  List<String> messageFlags;
  List<String> permanentMessageFlags;

  /// Map of extended results
  Map<String, List<String>> extendedData = {};

  /// This is set to false in case the server supports CONDSTORE but no mod sequence for this mailbox
  bool hasModSequence;

  bool get isInbox => hasFlag(MailboxFlag.inbox);
  bool get isDrafts => hasFlag(MailboxFlag.drafts);
  bool get isSent => hasFlag(MailboxFlag.sent);
  bool get isJunk => hasFlag(MailboxFlag.junk);
  bool get isTrash => hasFlag(MailboxFlag.trash);
  bool get isArchive => hasFlag(MailboxFlag.archive);

  bool get isSpecialUse =>
      isInbox || isDrafts || isSent || isJunk || isTrash || isArchive;

  Mailbox();
  Mailbox.setup(String name, String path, this.flags) {
    this.name = name;
    this.path = path;
    if (name.toUpperCase() == 'INBOX' && !isInbox) {
      flags.add(MailboxFlag.inbox);
    }
    isMarked = hasFlag(MailboxFlag.marked);
    hasChildren = hasFlag(MailboxFlag.hasChildren);
    isSelected = hasFlag(MailboxFlag.select);
    isUnselectable = hasFlag(MailboxFlag.noSelect);
  }

  bool hasFlag(MailboxFlag flag) {
    return flags.contains(flag);
  }

  Mailbox getParent(List<Mailbox> knownMailboxes, String separator,
      {bool create = true, bool createIntermediate = true}) {
    var lastSplitIndex = path.lastIndexOf(separator);
    if (lastSplitIndex == -1) {
      // this is a root mailbox, eg 'Inbox'
      return null;
    }
    var parentPath = path.substring(0, lastSplitIndex);
    var parent = knownMailboxes.firstWhere((box) => box.path == parentPath,
        orElse: () => null);
    if (parent == null && create) {
      lastSplitIndex = parentPath.lastIndexOf(separator);
      var parentName = lastSplitIndex == -1
          ? parentPath
          : parentPath.substring(lastSplitIndex + 1);
      parent = Mailbox.setup(parentName, parentPath, [MailboxFlag.noSelect]);
      if ((lastSplitIndex != -1) && (!createIntermediate)) {
        parent = parent.getParent(knownMailboxes, separator,
            create: true, createIntermediate: false);
      }
    }
    return parent;
  }

  @override
  String toString() {
    var buffer = StringBuffer()..write('"')..write(path)..write('"');
    if (messagesExists != null) {
      buffer
        ..write(' exists: ')
        ..write(messagesExists)
        ..write(', highestModeSequence: ')
        ..write(highestModSequence);
    }
    return buffer.toString();
  }

  /// Helper method to encode the specified [path] in Modified UTF7 encoding.
  static String encode(String path) {
    return _modifiedUtf7Codec.encodeText(path);
  }
}
