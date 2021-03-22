import 'package:enough_mail/enough_mail.dart';

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

  /// Creates a new result for an delete call
  DeleteResult(
    this.isUndoable,
    this.action,
    this.originalSequence,
    this.originalMailbox,
    this.targetSequence,
    this.targetMailbox,
  );

  /// Reverses the result so that the original sequence and mailbox becomes the target ones.
  DeleteResult reverse() {
    return DeleteResult(isUndoable, action, targetSequence, targetMailbox,
        originalSequence, originalMailbox);
  }

  /// Reverses the result and includes the new sequence from the given CopyUidResult.
  DeleteResult reverseWith(UidResponseCode? result) {
    if (result?.targetSequence != null) {
      return DeleteResult(isUndoable, action, result!.originalSequence,
          targetMailbox, result.targetSequence, originalMailbox);
    }
    return reverse();
  }
}
