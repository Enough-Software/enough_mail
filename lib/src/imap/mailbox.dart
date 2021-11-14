import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_mail/src/codecs/modified_utf7_codec.dart';
import 'package:enough_mail/src/imap/qresync.dart';

/// Contains common flags for mailboxes
enum MailboxFlag {
  /// a marked mailbox
  marked,

  /// a not marked mailbox
  unMarked,

  /// a mailbox with other mailboxes inside
  hasChildren,

  /// a mailbox leaf
  hasNoChildren,

  /// a mailbox that cannot be selected
  noSelect,

  /// a mailbox that can be selected
  select,

  /// a mailbox without inferios boxes
  noInferior,

  /// the user has subscribed this mailbox
  subscribed,

  /// this mailbox is at a remote service
  remote,

  /// this mailbox does not exist
  nonExistent,

  /// this mailbox contains all messages
  all,

  /// this mailbox is the inbox
  inbox,

  /// this mailbox contains sent messages
  sent,

  /// this mailbox contains draft messages
  drafts,

  /// this mailbox contains junk messages
  junk,

  /// this mailbox contains deleted messages
  trash,

  /// this mailbox contains archived messages
  archive,

  /// this mailbox contains flagged messages
  flagged
}

/// Stores meta data about a folder aka Mailbox
class Mailbox {
  /// Creates a new uninitialized Mailbox
  Mailbox();

  /// Creates a new mailbox with the specified [name], [path] and [flags].
  ///
  /// Optionally specify the path separator with [pathSeparator]
  Mailbox.setup(String name, String path, this.flags, {String? pathSeparator}) {
    this.name = name;
    this.path = path;
    if (pathSeparator != null) {
      this.pathSeparator = pathSeparator;
    }
    if (name.toUpperCase() == 'INBOX' && !isInbox) {
      flags.add(MailboxFlag.inbox);
    }
    isMarked = hasFlag(MailboxFlag.marked);
    hasChildren = hasFlag(MailboxFlag.hasChildren);
    isSelected = hasFlag(MailboxFlag.select);
    isUnselectable = hasFlag(MailboxFlag.noSelect);
  }

  static const ModifiedUtf7Codec _modifiedUtf7Codec = ModifiedUtf7Codec();

  /// The path separator like `/` or `:`.
  late String pathSeparator;

  /// The encoded name
  String get encodedName => _modifiedUtf7Codec.encodeText(_name);
  late String _name;

  /// The name of this box
  String get name => _name;

  /// Retrieves the quick resync settings of this mailbox
  ///
  /// Note that this is only supported when the server supports the
  /// `QRESYNC` extension.
  QResyncParameters? get qresync =>
      (highestModSequence == null || uidValidity == null)
          ? null
          : QResyncParameters(uidValidity, highestModSequence);
  set name(String value) => _name = _modifiedUtf7Codec.decodeText(value);

  /// The encoded path
  String get encodedPath => _encodedPath;
  late String _encodedPath;
  late String _path;

  /// The path
  String get path => _path;
  set path(String value) {
    _path = _modifiedUtf7Codec.decodeText(value);
    _encodedPath = value;
  }

  /// Is this mailbox marked?
  bool isMarked = false;

  /// Does this mailbox have children?
  bool hasChildren = false;

  /// Is this mailbox selected?
  bool isSelected = false;

  /// Can this mailbox not be selected?
  bool isUnselectable = false;

  /// Number of messages deeemed by the server as recent
  int? messagesRecent;

  /// The number of  messages in this mailbox
  int messagesExists = 0;

  /// The number of unseen messages - only reported through STATUS calls
  int? messagesUnseen;

  /// The sequence ID of the first unseen message
  int? firstUnseenMessageSequenceId;

  /// The UID validity of this mailbox
  int? uidValidity;

  /// The expected UID of the next incoming message
  int? uidNext;

  /// Can the user both read and write this mailbox?
  bool isReadWrite = false;

  /// The last modification sequence in case the server supports the
  /// `CONDSTORE` or `QRESYNC` capability. Useful for message synchronization.
  int? highestModSequence;

  /// The flags of this mailbox
  List<MailboxFlag> flags = <MailboxFlag>[];

  /// Supported flags for messages in this mailbox
  List<String>? messageFlags;

  /// Supported permanent flags for messages in this mailbox
  List<String>? permanentMessageFlags;

  /// Map of extended results
  Map<String, List<String>> extendedData = {};

  /// This is set to false in case the server supports CONDSTORE but no
  /// mod sequence for this mailbox
  bool? hasModSequence;

  /// Is this the inbox?
  bool get isInbox => hasFlag(MailboxFlag.inbox);

  /// Is this the drafts folder?
  bool get isDrafts => hasFlag(MailboxFlag.drafts);

  /// Is this the sent folder?
  bool get isSent => hasFlag(MailboxFlag.sent);

  /// Is this the junk folder?
  bool get isJunk => hasFlag(MailboxFlag.junk);

  /// Is this the trash folder?
  bool get isTrash => hasFlag(MailboxFlag.trash);

  /// Is this the archive folder?
  bool get isArchive => hasFlag(MailboxFlag.archive);

  /// Does this mailbox have a known specific purpose?
  bool get isSpecialUse =>
      isInbox || isDrafts || isSent || isJunk || isTrash || isArchive;

  /// Checks of the mailbox has the given flag
  bool hasFlag(MailboxFlag flag) => flags.contains(flag);

  /// Tries to determine the parent mailbox
  /// from the given [knownMailboxes] and [separator].
  ///
  /// Set [create] to `false` in case the parent should only be determined
  /// from the known mailboxes (defaults to `true`).
  /// Set [createIntermediate] to `false` and  [create] to `true` to return
  /// the first known existing parent, when the direct parent is not known
  Mailbox? getParent(List<Mailbox> knownMailboxes, String separator,
      {bool create = true, bool createIntermediate = true}) {
    var lastSplitIndex = path.lastIndexOf(separator);
    if (lastSplitIndex == -1) {
      // this is a root mailbox, eg 'Inbox'
      return null;
    }
    final parentPath = path.substring(0, lastSplitIndex);
    var parent =
        knownMailboxes.firstWhereOrNull((box) => box.path == parentPath);
    if (parent == null && create) {
      lastSplitIndex = parentPath.lastIndexOf(separator);
      final parentName = (lastSplitIndex == -1)
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
    final buffer = StringBuffer()
      ..write('"')
      ..write(path)
      ..write('"')
      ..write(' exists: ')
      ..write(messagesExists)
      ..write(', highestModeSequence: ')
      ..write(highestModSequence)
      ..write(', flags: ')
      ..write(flags);
    return buffer.toString();
  }

  /// Helper method to encode the specified [path] in Modified UTF7 encoding.
  static String encode(String path) => _modifiedUtf7Codec.encodeText(path);

  /// Sets the name from the original path
  ///
  /// This can be useful when the mailbox name was localized
  /// for viewing purposes.
  void setNameFromPath() {
    final splitIndex = _encodedPath.lastIndexOf(pathSeparator);
    if (splitIndex == -1 || splitIndex == _encodedPath.length - 1) {
      name = _encodedPath;
    } else {
      name = _encodedPath.substring(splitIndex);
    }
  }
}
