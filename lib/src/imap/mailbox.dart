import 'package:collection/collection.dart' show IterableExtension;

import '../codecs/modified_utf7_codec.dart';
import 'qresync.dart';

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

  /// a mailbox without inferiors boxes
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
  flagged,

  /// a virtual, not existing mailbox
  ///
  /// Compare [Mailbox.virtual]
  virtual,
}

/// Stores meta data about a folder aka Mailbox
class Mailbox {
  /// Creates a new Mailbox
  Mailbox({
    required this.encodedName,
    required this.encodedPath,
    required this.flags,
    required this.pathSeparator,
    this.isReadWrite = false,
    this.messagesRecent = 0,
    this.messagesExists = 0,
    this.messagesUnseen = 0,
    this.highestModSequence,
    this.firstUnseenMessageSequenceId,
    this.uidNext,
    this.uidValidity,
    this.messageFlags = const [],
    this.permanentMessageFlags = const [],
    this.extendedData = const {},
  })  : name = _modifiedUtf7Codec.decodeText(encodedName),
        path = _modifiedUtf7Codec.decodeText(encodedPath) {
    if (!isInbox && name.toLowerCase() == 'inbox') {
      flags.add(MailboxFlag.inbox);
    }
  }

  /// Creates a new mailbox with the specified [name], [path] and [flags].
  ///
  /// Optionally specify the path separator with [pathSeparator]
  @Deprecated('Use Mailbox() constructor directly')
  Mailbox.setup(
    String name,
    String path,
    List<MailboxFlag> flags, {
    String? pathSeparator,
  }) : this(
            encodedName: name,
            encodedPath: path,
            flags: flags,
            pathSeparator: pathSeparator ?? '/');

  /// Creates a new virtual mailbox
  ///
  /// A virtual mailbox has the flag [MailboxFlag.virtual] and is not
  /// a mailbox that exists for real.
  Mailbox.virtual(String name, List<MailboxFlag> flags)
      : this(
            encodedName: name,
            encodedPath: name,
            flags: flags.addIfNotPresent(MailboxFlag.virtual),
            pathSeparator: '/');

  /// Copies this mailbox with the given parameters
  Mailbox copyWith({
    int? messagesRecent,
    int? messagesExists,
    int? messagesUnseen,
    int? highestModSequence,
    int? uidNext,
    List<String>? messageFlags,
    List<String>? permanentMessageFlags,
    Map<String, List<String>>? extendedData,
  }) =>
      Mailbox(
        encodedName: encodedName,
        encodedPath: encodedPath,
        flags: flags,
        pathSeparator: pathSeparator,
        isReadWrite: isReadWrite,
        messagesRecent: messagesRecent ?? this.messagesRecent,
        messagesExists: messagesExists ?? this.messagesExists,
        highestModSequence: highestModSequence ?? this.highestModSequence,
        uidNext: uidNext ?? this.uidNext,
        uidValidity: uidValidity,
        firstUnseenMessageSequenceId: firstUnseenMessageSequenceId,
        messageFlags: messageFlags ?? this.messageFlags,
        permanentMessageFlags:
            permanentMessageFlags ?? this.permanentMessageFlags,
        extendedData: extendedData ?? this.extendedData,
      );

  static const ModifiedUtf7Codec _modifiedUtf7Codec = ModifiedUtf7Codec();

  /// The encoded name of the mailbox
  final String encodedName;

  /// The encoded path
  final String encodedPath;

  /// The human readable path
  final String path;

  /// The separator between path elements, usually `/` or `:`.
  final String pathSeparator;

  /// The human readable name of this box
  String name;

  /// Number of messages deemed by the server as recent
  int messagesRecent;

  /// The number of  messages in this mailbox
  int messagesExists;

  /// The number of unseen messages - only reported through STATUS calls
  int messagesUnseen;

  /// The sequence ID of the first unseen message
  int? firstUnseenMessageSequenceId;

  /// The UID validity of this mailbox
  int? uidValidity;

  /// The expected UID of the next incoming message
  int? uidNext;

  /// Can the user both read and write this mailbox?
  bool isReadWrite;

  /// The last modification sequence in case the server supports the
  /// `CONDSTORE` or `QRESYNC` capability. Useful for message synchronization.
  int? highestModSequence;

  /// The flags of this mailbox
  final List<MailboxFlag> flags;

  /// Supported flags for messages in this mailbox
  List<String> messageFlags;

  /// Supported permanent flags for messages in this mailbox
  List<String> permanentMessageFlags;

  /// Map of extended results
  final Map<String, List<String>> extendedData;

  /// Retrieves the quick resync settings of this mailbox
  ///
  /// Note that this is only supported when the server supports the
  /// `QRESYNC` extension.
  QResyncParameters? get qresync =>
      (highestModSequence == null || uidValidity == null)
          ? null
          : QResyncParameters(uidValidity, highestModSequence);

  /// Is this mailbox marked?
  bool get isMarked => hasFlag(MailboxFlag.marked);

  /// Does this mailbox have children?
  bool get hasChildren => hasFlag(MailboxFlag.hasChildren);

  /// Is this mailbox selected?
  bool get isSelected => hasFlag(MailboxFlag.select);

  /// Can this mailbox not be selected?
  @Deprecated('Use isNotSelectable instead')
  bool get isUnselectable => hasFlag(MailboxFlag.noSelect);

  /// Can this mailbox not be selected?
  bool get isNotSelectable => hasFlag(MailboxFlag.noSelect);

  /// This is set to false in case the server supports CONDSTORE but no
  /// mod sequence for this mailbox
  bool get hasModSequence => highestModSequence != null;

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

  /// Is this a virtual mailbox?
  ///
  /// A virtual mailbox does not exist in reality.
  /// Compare [Mailbox.virtual]
  bool get isVirtual => hasFlag(MailboxFlag.virtual);

  /// Does this mailbox have a known specific purpose?
  bool get isSpecialUse =>
      isInbox || isDrafts || isSent || isJunk || isTrash || isArchive;

  /// Checks of the mailbox has the given flag
  bool hasFlag(MailboxFlag flag) => flags.contains(flag);

  /// Sets the name from the original path
  ///
  /// This can be useful when the mailbox name was localized
  /// for viewing purposes.
  ///
  /// Compare [name]
  void setNameFromPath() {
    name = _modifiedUtf7Codec.decodeText(encodedName);
  }

  /// Tries to determine the parent mailbox
  /// from the given [knownMailboxes] and [separator].
  ///
  /// Set [create] to `false` in case the parent should only be determined
  /// from the known mailboxes (defaults to `true`).
  /// Set [createIntermediate] to `false` and  [create] to `true` to return
  /// the first known existing parent, when the direct parent is not known
  Mailbox? getParent(List<Mailbox> knownMailboxes, String separator,
      {bool create = true, bool createIntermediate = true}) {
    var lastSplitIndex = encodedPath.lastIndexOf(separator);
    if (lastSplitIndex == -1) {
      // this is a root mailbox, eg 'Inbox'
      return null;
    }
    final parentPath = encodedPath.substring(0, lastSplitIndex);
    var parent =
        knownMailboxes.firstWhereOrNull((box) => box.path == parentPath);
    if (parent == null && create) {
      lastSplitIndex = parentPath.lastIndexOf(separator);
      final parentName = (lastSplitIndex == -1)
          ? parentPath
          : parentPath.substring(lastSplitIndex + 1);
      parent = Mailbox(
        encodedName: parentName,
        encodedPath: parentPath,
        flags: [MailboxFlag.noSelect],
        pathSeparator: separator,
      );
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
  ///
  /// Note that any path separators will be encoded as well, so
  /// you might have to separate and reassemble path element manually
  static String encode(String path, String pathSeparator) {
    final pathSeparatorIndex = path.lastIndexOf(pathSeparator);
    if (pathSeparatorIndex == -1) {
      return _modifiedUtf7Codec.encodeText(path);
    } else {
      final start = path.substring(0, pathSeparatorIndex);
      final end = _modifiedUtf7Codec.encodeText(
          path.substring(pathSeparatorIndex + pathSeparator.length));
      return '$start$pathSeparator$end';
    }
  }
}

extension _ListExtension<T> on List<T> {
  List<T> addIfNotPresent(T element) {
    if (!contains(element)) {
      add(element);
    }
    return this;
  }
}
