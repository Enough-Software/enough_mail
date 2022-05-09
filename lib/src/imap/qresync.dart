import '../exception.dart';
import 'message_sequence.dart';

/// Classes for implementing QRESYNC https://tools.ietf.org/html/rfc7162

/// QRESYNC parameters when doing a SELECT or EXAMINE.
class QResyncParameters {
  /// Creates new quick resync parameters
  QResyncParameters(this.lastKnownValidity, this.lastKnownModificationSequence);

  /// the last known UIDVALIDITY of the mailbox / folder
  int? lastKnownValidity;

  /// the last known modification sequence of the mailbox / folder
  int? lastKnownModificationSequence;

  /// the optional set of known UIDs
  MessageSequence? knownUids;

  /// an optional parenthesized list of known sequence ranges and their
  /// corresponding UIDs
  MessageSequence? _knownSequenceIds;

  /// corresponding UIDs to the known sequence IDs
  MessageSequence? _knownSequenceIdsUids;

  /// Specifies the optional known message sequence IDs with [knownSequenceIds]
  /// along with their corresponding UIds [correspondingKnownUids].
  void setKnownSequenceIdsWithTheirUids(MessageSequence knownSequenceIds,
      MessageSequence correspondingKnownUids) {
    if (knownSequenceIds == correspondingKnownUids) {
      throw InvalidArgumentException(
          'Invalid known and sequence ids are the same $knownSequenceIds');
    }
    _knownSequenceIds = knownSequenceIds;
    _knownSequenceIdsUids = correspondingKnownUids;
  }

  @override
  String toString() {
    final buffer = StringBuffer();
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
    final knownUids = this.knownUids;
    if (knownUids != null) {
      buffer.write(' ');
      knownUids.render(buffer);
      final _knownSequenceIds = this._knownSequenceIds;
      final _knownSequenceIdsUids = this._knownSequenceIdsUids;
      if (_knownSequenceIds != null && _knownSequenceIdsUids != null) {
        buffer.write(' (');
        _knownSequenceIds.render(buffer);
        buffer.write(' ');
        _knownSequenceIdsUids.render(buffer);
        buffer.write(')');
      }
    }
    buffer.write(')');
  }
}
