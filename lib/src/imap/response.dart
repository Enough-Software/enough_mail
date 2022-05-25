import '../../enough_mail.dart';

/// Status for command responses.
enum ResponseStatus {
  /// The response completed successfully
  ok,

  /// The command is not supported
  no,

  /// The command is supported but the client send a wrong request
  /// or is a wrong state
  bad
}

/// Base class for command responses.
class Response<T> {
  /// The status, either OK or Failed
  ResponseStatus? status;

  /// The textual response details
  String? details;

  /// The result of the operation
  T? result;

  /// Returns `true` when the response status is OK
  bool get isOkStatus => status == ResponseStatus.ok;

  /// Returns `true` when the response status is not ok
  bool get isFailedStatus => !isOkStatus;
}

/// A generic result that provide details about the success or failure
/// of the command.
class GenericImapResult {
  /// A list of possible warnings
  final List<ImapWarning> warnings = <ImapWarning>[];

  /// Optional response code as text
  String? responseCode;

  /// Optional details as text
  String? details;

  /// Retrieves the APPENDUID details after an APPEND call,
  /// compare https://tools.ietf.org/html/rfc4315
  UidResponseCode? get responseCodeAppendUid =>
      _parseUidResponseCode('APPENDUID');

  /// Retrieves the COPYUID details after an COPY call,
  /// compare https://tools.ietf.org/html/rfc4315
  UidResponseCode? get responseCodeCopyUid => _parseUidResponseCode('COPYUID');

  UidResponseCode? _parseUidResponseCode(String name) {
    final responseCode = this.responseCode;
    if (responseCode != null && responseCode.startsWith(name)) {
      final uidParts = responseCode.substring(name.length + 1).split(' ');
      if (uidParts.length == 3) {
        if (uidParts[1].isEmpty || uidParts[2].isEmpty) {
          return null;
        }
        return UidResponseCode(
          int.parse(uidParts[0]),
          MessageSequence.parse(uidParts[1], isUidSequence: true),
          MessageSequence.parse(uidParts[2], isUidSequence: true),
        );
      } else if (uidParts.length == 2) {
        if (uidParts[1].isEmpty) {
          return null;
        }
        return UidResponseCode(
          int.parse(uidParts[0]),
          null,
          MessageSequence.parse(uidParts[1], isUidSequence: true),
        );
      }
    }
    return null;
  }
}

/// Result for FETCH operations
class FetchImapResult {
  /// Creates a new fetch result
  const FetchImapResult(this.messages, this.vanishedMessagesUidSequence,
      {this.modifiedSequence});

  /// Any messages that have been removed by other clients.
  /// This is only given from QRESYNC compliant servers after having enabled
  /// `QRESYNC` by the client.
  /// Clients must NOT use these vanished sequence to update their
  /// internal sequence IDs, because
  /// they have happened earlier.
  /// Compare https://tools.ietf.org/html/rfc7162 for details.
  final MessageSequence? vanishedMessagesUidSequence;

  /// The sequence of messages that have been modified
  final MessageSequence? modifiedSequence;

  /// The requested messages
  final List<MimeMessage> messages;

  /// Replaces matching messages
  void replaceMatchingMessages(List<MimeMessage> messages) {
    for (final mime in messages) {
      final uid = mime.uid;
      final sequenceId = mime.sequenceId;
      if (uid != null) {
        final index = messages.indexWhere((msg) => msg.uid == uid);
        if (index != -1) {
          messages[index] = mime;
        }
      } else if (sequenceId != null) {
        final index =
            messages.indexWhere((msg) => msg.sequenceId == sequenceId);
        if (index != -1) {
          messages[index] = mime;
        }
      }
    }
  }
}

/// Result for STORE and UID STORE operations
class StoreImapResult {
  /// A list of messages that have been updated
  List<MimeMessage>? changedMessages;

  /// A list of IDs of messages that have been modified on the server side.
  /// The IDs are sequence IDs for STORE and UIDs for UID STORE commands.
  /// The modified IDs can only be returned when the unchangedSinceModSequence
  /// parameter has been specified.
  MessageSequence? modifiedMessageSequence;
}

/// Result for SEARCH and UID SEARCH operations
class SearchImapResult {
  /// A list of message IDs
  MessageSequence? matchingSequence;

  /// The highest modification sequence in the searched messages
  /// The modification sequence can only be returned when the `MODSEQ` search
  /// criteria has been used and when the server supports the
  /// `CONDSTORE` capability.
  int? highestModSequence;

  /// Identifies an extended search result
  bool? isExtended;

  /// Result tag
  String? tag;

  /// Minimum found message ID or UID
  int? min;

  /// Maximum found message ID or UID
  int? max;

  /// Matches count
  int? count;

  /// Range of the partial result returned
  String? partialRange;

  /// Is this a partial search response?
  bool get isPartial {
    final partialRange = this.partialRange;
    return partialRange != null && partialRange.isNotEmpty;
  }
}

/// Contains a UID response code
class UidResponseCode {
  /// Creates a new response code
  const UidResponseCode(
      this.uidValidity, this.originalSequence, this.targetSequence);

  /// The UID validity
  final int uidValidity;

  /// The optional original sequence
  final MessageSequence? originalSequence;

  /// The optional target sequence
  final MessageSequence targetSequence;
}

/// Warnings can often be ignored but provide more insights in case of problems
/// They are given in untagged responses of the server.
class ImapWarning {
  /// Creates a new warning instance
  const ImapWarning(this.type, this.details);

  /// Either 'BAD' or 'NO'
  final String type;

  /// The human readable error
  final String details;
}

/// Result for QUOTA operations
class QuotaResult {
  /// Creates a new quota result
  const QuotaResult(this.rootName, this.resourceLimits);

  /// The optional name of the root
  final String? rootName;

  /// The resource limits
  final List<ResourceLimit> resourceLimits;
}

/// Result for QUOTAROOT operations
class QuotaRootResult {
  /// Creates a new quota root result
  QuotaRootResult(this.mailboxName, this.rootNames);

  /// The name of the associated mailbox
  final String mailboxName;

  /// All names in this root
  final List<String> rootNames;

  /// The quota results
  Map<String?, QuotaResult> quotaRoots = {};
}

/// Result for SORT and UID SORT operations
///
/// Copy of [SearchImapResult] class because SEARCH and SORT are equivalents
class SortImapResult {
  /// A list of message IDs
  MessageSequence? matchingSequence;

  /// The highest modification sequence in the searched messages
  ///
  /// The modification sequence can only be returned when the `MODSEQ` search
  /// criteria has been used and when the server supports the
  /// `CONDSTORE` capability.
  int? highestModSequence;

  /// Signals an extended sort result
  bool? isExtended;

  /// Result tag
  String? tag;

  /// Minimum found message ID or UID
  int? min;

  /// Maximum found message ID or UID
  int? max;

  /// Matches count
  int? count;

  /// Range of the partial result returned
  String? partialRange;

  /// Is this a partial response?
  bool get isPartial {
    final partialRange = this.partialRange;
    return partialRange != null && partialRange.isNotEmpty;
  }
}
