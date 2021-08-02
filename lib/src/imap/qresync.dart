import 'package:enough_mail/src/imap/message_sequence.dart';

/// Classes for implementing QRESYNC https://tools.ietf.org/html/rfc7162

/// QRESYNC parameters when doing a SELECT or EXAMINE.
class QResyncParameters {
  /// the last known UIDVALIDITY of the mailbox / folder
  int? lastKnownValidity;

  /// the last known modification sequence of the mailbox / folder
  int? lastKnownModificationSequence;

  /// the optional set of known UIDs
  MessageSequence? knownUids;

  /// an optional parenthesized list of known sequence ranges and their corresponding UIDs
  MessageSequence? _knownSequenceIds;

  /// corresponding UIDs to the known sequence IDs
  MessageSequence? _knownSequenceIdsUids;

  QResyncParameters(this.lastKnownValidity, this.lastKnownModificationSequence);

  /// Specifies the optional known message sequence IDs with [knownSequenceIds] along with their corresponding UIds [correspondingKnownUids].
  void setKnownSequenceIdsWithTheirUids(MessageSequence knownSequenceIds,
      MessageSequence correspondingKnownUids) {
    if (knownSequenceIds == correspondingKnownUids) {
      throw StateError(
          'Invalid known and sequence ids are the same $knownSequenceIds');
    }
    _knownSequenceIds = knownSequenceIds;
    _knownSequenceIdsUids = correspondingKnownUids;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    render(buffer);
    return buffer.toString();
  }

  /// Renders this parameter for an IMAP SELECT or EXAMINE command.
  void render(StringBuffer buffer) {
    buffer
      ..write('QRESYNC (')
      ..write(lastKnownValidity)
      ..write(' ')
      ..write(lastKnownModificationSequence);
    if (knownUids != null) {
      buffer.write(' ');
      knownUids!.render(buffer);
      if (_knownSequenceIds != null && _knownSequenceIdsUids != null) {
        buffer.write(' (');
        _knownSequenceIds!.render(buffer);
        buffer.write(' ');
        _knownSequenceIdsUids!.render(buffer);
        buffer.write(')');
      }
    }
    buffer.write(')');
  }
}
