import 'package:enough_mail/enough_mail.dart';
import 'package:collection/collection.dart' show IterableExtension;

/// The internal action that was used for deletion.
/// This is useful for undoing and delete operation.
enum DeleteAction {
  /// The message(s) were marked as deleted with a flag
  flag,

  /// The message(s) were moved
  move,

  /// The message(s) were copied and then flagged
  copy,

  /// The message(s) were deleted via POP3 protocol
  pop,
}

/// Provides information about a delete action
class DeleteResult {
  /// Is this delete result undoable?
  bool isUndoable;

  /// The internal action that was used to delete
  final DeleteAction action;

  /// The originating mailbox
  final Mailbox? originalMailbox;

  /// The original message sequence used
  final MessageSequence? originalSequence;

  /// The resulting message sequence of the deleted messages
  final MessageSequence? targetSequence;

  /// The target mailbox, can be null
  final Mailbox? targetMailbox;

  /// The associated mail client
  final MailClient mailClient;

  /// Creates a new result for an delete call
  DeleteResult(
    this.isUndoable,
    this.action,
    this.originalSequence,
    this.originalMailbox,
    this.targetSequence,
    this.targetMailbox,
    this.mailClient,
  );

  /// Reverses the result so that the original sequence and mailbox becomes the target ones.
  DeleteResult reverse() {
    return DeleteResult(isUndoable, action, targetSequence, targetMailbox,
        originalSequence, originalMailbox, mailClient);
  }

  /// Reverses the result and includes the new sequence from the given CopyUidResult.
  DeleteResult reverseWith(UidResponseCode? result) {
    if (result?.targetSequence != null) {
      return DeleteResult(isUndoable, action, originalSequence, targetMailbox,
          result!.targetSequence, originalMailbox, mailClient);
    }
    return reverse();
  }
}

/// Possible move implementations
enum MoveAction {
  /// Messages were moved using the `MOVE` extension
  move,

  /// Messages were copied to the target mailbox and then deleted on the originating mailbox
  copy
}

class MoveResult {
  /// Is this delete result undoable?
  bool isUndoable;

  /// The internal action that was used to delete
  final MoveAction action;

  /// The originating mailbox
  final Mailbox? originalMailbox;

  /// The original message sequence used
  final MessageSequence? originalSequence;

  /// The resulting message sequence of the moved messages
  final MessageSequence? targetSequence;

  /// The target mailbox
  final Mailbox? targetMailbox;

  /// The associated mail client
  final MailClient mailClient;

  /// Creates a new result for an move call
  MoveResult(
    this.isUndoable,
    this.action,
    this.originalSequence,
    this.originalMailbox,
    this.targetSequence,
    this.targetMailbox,
    this.mailClient,
  );

  /// Reverses the result so that the original sequence and mailbox becomes the target ones.
  MoveResult reverse() {
    return MoveResult(isUndoable, action, targetSequence, targetMailbox,
        originalSequence, originalMailbox, mailClient);
  }
}

/// Encapsulates a thread result
class ThreadResult {
  /// The source data
  final SequenceNode threadData;

  /// The paged message sequence
  final PagedMessageSequence threadSequence;

  /// The thread preference
  final ThreadPreference threadPreference;

  /// The fetch preference
  final FetchPreference fetchPreference;

  /// Since when the thread data is retrieved
  final DateTime since;

  /// The threads that have been fetched so far
  final List<MimeThread> threads;

  /// Retrieves the total number of threads which can be higher than [threads.length].
  int get length => threadData.length;

  /// Checks if the [threadSequence] has a next page
  bool get hasMoreResults => threadSequence.hasNext;

  /// Shortcut to find out if this thread result is UID based
  bool get isUidBased => threadSequence.isUidSequence;

  /// Creates a new result with the given [threadData], [threadSequence], [threadPreference], [fetchPreference] and the prefetched [threads].
  ThreadResult(this.threadData, this.threadSequence, this.threadPreference,
      this.fetchPreference, this.since, this.threads);

  /// Eases access to the [MimeThread] at the specified [threadIndex] or `null` when it is not yet loaded.
  ///
  /// Note that the [threadIndex] is expected to be based on full [threadData], meaning 0 is the newest  thread and length-1 is the oldest  thread.
  MimeThread? operator [](int threadIndex) {
    final index = (length - threadIndex - 1);
    if (index < 0 || threadIndex < 0) {
      return null;
    }
    return threads[threadIndex];
  }

  /// Distributes the given [unthreadedMessages] to the [threads] managed by this result.
  void addAll(List<MimeMessage> unthreadedMessages) {
    // the new messages could
    // a) complement existing threads, but only when threadPreference is ThreadPreference.all, or
    // b) create complete new threads
    final isUid = threadData.isUid;
    if (threadPreference == ThreadPreference.latest) {
      for (final node in threadData.children.reversed) {
        final id = node.latestId;
        final message = isUid
            ? unthreadedMessages.firstWhereOrNull((msg) => msg.uid == id)
            : unthreadedMessages
                .firstWhereOrNull((msg) => msg.sequenceId == id);
        if (message != null) {
          final thread = MimeThread(node.toMessageSequence(), [message]);
          threads.insert(0, thread);
        }
      }
      threads.sort((t1, t2) => isUid
          ? t1.latest.uid!.compareTo(t2.latest.uid!)
          : t1.latest.sequenceId!.compareTo(t2.latest.sequenceId!));
    } else {
      // check if there are messages for already existing threads:
      for (final thread in threads) {
        if (thread.hasMoreMessages) {
          final ids = thread.missingMessageSequence.toList().reversed;
          for (final id in ids) {
            final message = isUid
                ? unthreadedMessages.firstWhereOrNull((msg) => msg.uid == id)
                : unthreadedMessages
                    .firstWhereOrNull((msg) => msg.sequenceId == id);
            if (message != null) {
              unthreadedMessages.remove(message);
              thread.messages.insert(0, message);
            }
          }
        }
      }
      // now check if there are more threads:
      if (unthreadedMessages.isNotEmpty) {
        for (final node in threadData.children.reversed) {
          final threadSequence = node.toMessageSequence();
          final threadedMessages = <MimeMessage>[];
          final ids = threadSequence.toList();
          for (final id in ids) {
            final message = isUid
                ? unthreadedMessages.firstWhereOrNull((msg) => msg.uid == id)
                : unthreadedMessages
                    .firstWhereOrNull((msg) => msg.sequenceId == id);
            if (message != null) {
              threadedMessages.add(message);
            }
          }
          if (threadedMessages.isNotEmpty) {
            final thread = MimeThread(threadSequence, threadedMessages);
            threads.add(thread);
          }
        }
        threads.sort((t1, t2) => isUid
            ? t1.latest.uid!.compareTo(t2.latest.uid!)
            : t1.latest.sequenceId!.compareTo(t2.latest.sequenceId!));
      }
    }
  }

  /// Checks if the page for the given thread [threadIndex] is already requested in a [ThreadPreference.latest] based result.
  ///
  /// Note that the [threadIndex] is expected to be based on full [threadData], meaning 0 is the newest thread and length-1 is the oldest thread.
  bool isPageRequestedFor(int threadIndex) {
    assert(threadPreference == ThreadPreference.latest,
        'This call is only valid for ThreadPreference.latest');
    final index = (length - threadIndex - 1);
    return index >
        length - (threadSequence.currentPageIndex * threadSequence.pageSize);
  }
}

/// Contains information about threads
///
/// Retrieve the thread sequence for a given message UID with `threadDataResult[uid]`.
/// Example:
/// ```dart
/// final sequence = threadDataResult[mimeMessage.uid];
/// if (sequence != null) {
///   // the mimeMessage belongs to a thread
/// }
/// ```
class ThreadDataResult {
  /// The source data
  final SequenceNode data;

  /// The day since when threads were requested
  final DateTime since;

  final _sequencesById = <int, MessageSequence>{};

  /// Creates a new result with the given [data] and [since].
  ThreadDataResult(this.data, this.since) {
    for (final node in data.children) {
      if (node.isNotEmpty) {
        final sequence = node.toMessageSequence();
        final ids = sequence.toList();
        if (ids.length > 1) {
          for (final id in ids) {
            _sequencesById[id] = sequence;
          }
        }
      }
    }
  }

  /// Checks if the given [id] belongs to a thread.
  bool hasThread(int id) {
    return _sequencesById[id] != null;
  }

  /// Retrieves the thread sequence for the given message [id].
  MessageSequence? operator [](int id) => _sequencesById[id];

  /// Sets the [MimeMessage.threadSequence] for the specified [mimeMessage]
  void setThreadSequence(MimeMessage mimeMessage) {
    final id = data.isUid ? mimeMessage.uid : mimeMessage.sequenceId;
    final sequence = _sequencesById[id];
    mimeMessage.threadSequence = sequence;
  }
}

/// Base class for actions that result in a partial fetching of messages
class PagedMessageResult {
  /// The message sequence containing all IDs or UIDs, may be null for empty searches
  final PagedMessageSequence pagedSequence;

  /// The number of all matching messages
  int get length => pagedSequence.length;

  /// Checks if this result is empty
  bool get isEmpty => length == 0;

  /// Checks if this result is not empty
  bool get isNotEmpty => length > 0;

  /// The fetched messages, initially this contains only the first page
  final List<MimeMessage> messages;

  /// The original fetch preference
  final FetchPreference fetchPreference;

  /// Checks if the [messageSequence] has a next page
  bool get hasMoreResults => pagedSequence.hasNext;

  /// Shortcut to find out if this search result is UID based
  bool get isUidBased => pagedSequence.isUidSequence;

  /// Creates a new paged result with the given [messageSequence], [messages] and [fetchPreference]
  PagedMessageResult(this.pagedSequence, this.messages, this.fetchPreference);

  /// Creates a new empty paged message result with the option [fetchPreference] ([FetchPreference.envelope]) and [pageSize](`30`).
  PagedMessageResult.empty(
      {FetchPreference fetchPreference = FetchPreference.envelope,
      int pageSize = 30})
      : this(PagedMessageSequence.empty(pageSize: pageSize), [],
            fetchPreference);

  /// Inserts the given [page] of messages to this result
  void insertAll(List<MimeMessage> page) => messages.insertAll(0, page);

  /// Adds the specified message to this search result.
  void addMessage(MimeMessage message) {
    final id = isUidBased ? message.uid! : message.sequenceId!;
    pagedSequence.add(id);
    messages.add(message);
  }

  /// Adds the specified message to this search result.
  void removeMessage(MimeMessage message) {
    final id = isUidBased ? message.uid! : message.sequenceId!;
    pagedSequence.remove(id);
    messages.remove(message);
  }

  /// Removes the specified [removeSequence] from this result and returns all messages that have been loaded.
  ///
  /// Note that the [removeSequence] must be based on the same type of IDs (UID or sequence-ID) as this result.
  List<MimeMessage> removeMessageSequence(MessageSequence removeSequence) {
    assert(removeSequence.isUidSequence == pagedSequence.isUidSequence,
        'Not the same sequence ID types');
    final isUid = pagedSequence.isUidSequence;
    final ids = removeSequence.toList();
    final result = <MimeMessage>[];
    for (final id in ids) {
      pagedSequence.remove(id);
      final match = messages.firstWhereOrNull(
          (msg) => isUid ? msg.uid == id : msg.sequenceId == id);
      if (match != null) {
        result.add(match);
        messages.remove(match);
      }
    }
    return result;
  }

  /// Retrieves the message for the given [messageIndex].
  ///
  /// Note that the [messageIndex] is expected to be based on full [messageSequence], where index 0 is newest message and size-1 is the oldest message.
  /// Compare [isAvailable]
  MimeMessage operator [](int messageIndex) {
    final index = (messages.length - messageIndex - 1);
    if (index < 0) {
      throw RangeError(
          'for messageIndex $messageIndex in a result with the length $length and currently loaded message count of ${messages.length}');
    }
    return messages[index];
  }

  /// Checks if the message for the given [messageIndex] is already loaded.
  ///
  /// Note that the [messageIndex] is expected to be based on full [messageSequence], where index 0 is the oldest message and size-1 is the newest message.
  bool isAvailable(int messageIndex) {
    final index = (messages.length - messageIndex - 1);
    return (index >= 0 && messageIndex >= 0);
  }

  /// Retrieves the message ID at the specified [messageIndex].
  ///
  /// Note that the [messageIndex] is expected to be based on full [messageSequence], where index 0 is the oldest message and size-1 is the newest message.
  int messageIdAt(int messageIndex) {
    final index = (length - messageIndex - 1);
    return pagedSequence.sequence.elementAt(index);
  }

  /// Checks if the page for the given message [messageIndex] is already requested.
  ///
  /// Note that the [messageIndex] is expected to be based on full [messageSequence], where index 0 is the newest message and size-1 is the oldest message.
  bool isPageRequestedFor(int messageIndex) {
    final index = (length - messageIndex - 1);
    return index >
        length - (pagedSequence.currentPageIndex * pagedSequence.pageSize);
  }
}

/// Contains the result of a search
class MailSearchResult extends PagedMessageResult {
  /// The original search
  final MailSearch search;

  /// Creates a new search result
  MailSearchResult(this.search, PagedMessageSequence pagedSequence,
      List<MimeMessage> messages, FetchPreference fetchPreference)
      : super(pagedSequence, messages, fetchPreference);

  /// Creates a new empty search result
  MailSearchResult.empty(this.search)
      : super.empty(
            fetchPreference: search.fetchPreference, pageSize: search.pageSize);
}
