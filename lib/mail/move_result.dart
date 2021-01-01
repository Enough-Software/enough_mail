import 'package:enough_mail/imap/mailbox.dart';
import 'package:enough_mail/imap/message_sequence.dart';

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
  final Mailbox originalMailbox;

  /// The original message sequence used
  final MessageSequence originalSequence;

  /// The resulting message sequence of the moved messages
  final MessageSequence targetSequence;

  /// The target mailbox
  final Mailbox targetMailbox;

  /// Creates a new result for an move call
  MoveResult(
    this.isUndoable,
    this.action,
    this.originalSequence,
    this.originalMailbox,
    this.targetSequence,
    this.targetMailbox,
  );

  /// Reverses the result so that the original sequence and mailbox becomes the target ones.
  MoveResult reverse() {
    return MoveResult(isUndoable, action, targetSequence, targetMailbox,
        originalSequence, originalMailbox);
  }
}
