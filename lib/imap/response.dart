import 'package:enough_mail/enough_mail.dart';

/// Status for command responses.
enum ResponseStatus { OK, No, Bad }

/// Base class for command responses.
class Response<T> {
  /// The status, either OK or Failed
  ResponseStatus status;

  /// The textual reponse details
  String details;

  /// The result of the operation
  T result;

  bool get isOkStatus => status == ResponseStatus.OK;
  bool get isFailedStatus => !isOkStatus;
}

/// A generic result that provide details about the success or failure of the command.
class GenericImapResult {
  List<ImapWarning> warnings = <ImapWarning>[];
  String responseCode;
  String details;

  /// Retrieves the APPENDUID details after an APPEND call, compare https://tools.ietf.org/html/rfc4315
  UidResponseCode get responseCodeAppendUid =>
      _parseUidResponseCode('APPENDUID');

  /// Retrieves the COPYUID details after an COPY call, compare https://tools.ietf.org/html/rfc4315
  UidResponseCode get responseCodeCopyUid => _parseUidResponseCode('COPYUID');

  UidResponseCode _parseUidResponseCode(String name) {
    if (responseCode != null && responseCode.startsWith(name)) {
      var uidParts = responseCode.substring(name.length + 1).split(' ');
      if (uidParts.length == 3) {
        return UidResponseCode(
          int.parse(uidParts[0]),
          MessageSequence.parse(uidParts[1], isUidSequence: true),
          MessageSequence.parse(uidParts[2], isUidSequence: true),
        );
      } else if (uidParts.length == 2) {
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
  /// Any messages that have been removed by other clients.
  /// This is only given from QRESYNC compliant servers after having enabled QRESYNC by the client.
  /// Clients must NOT use these vanished sequence to update their internal sequence IDs, because
  /// they have happened earlier. Compare https://tools.ietf.org/html/rfc7162 for details.
  MessageSequence vanishedMessagesUidSequence;

  MessageSequence modifiedSequence;

  /// The requested messages
  List<MimeMessage> messages;

  FetchImapResult(this.messages, this.vanishedMessagesUidSequence,
      {this.modifiedSequence});
}

/// Result for STORE and UID STORE operations
class StoreImapResult {
  /// A list of messages that have been updated
  List<MimeMessage> changedMessages;

  /// A list of IDs of messages that have been modified on the server side.
  /// The IDs are sequence IDs for STORE and UIDs for UID STORE commands.
  /// The modified IDs can only be returned when the unchangedSinceModSequence parameter has been specified.
  MessageSequence modifiedMessageSequence;
}

/// Result for SEARCH and UID SEARCH operations
class SearchImapResult {
  /// A list of message IDs
  MessageSequence matchingSequence;

  /// The highest modification sequence in the searched messages
  /// The modification sequence can only be returned when the MODSEQ search criteria has been used and when the server supports the CONDSTORE capability.
  int highestModSequence;

  /// Identifies an extended search result
  bool isExtended;

  /// Result tag
  String tag;

  /// Minimum found message ID or UID
  int min;

  /// Maximum found message ID or UID
  int max;

  /// Matches count
  int count;
}

class UidResponseCode {
  int uidValidity;
  MessageSequence originalSequence;
  MessageSequence targetSequence;
  UidResponseCode(this.uidValidity, this.originalSequence, this.targetSequence);
}

/// Warnings can often be ignored but provide more insights in case of problems
/// They are given in untagged responses of the server.
class ImapWarning {
  /// Either 'BAD' or 'NO'
  String type;

  /// The human readable error
  String details;

  ImapWarning(this.type, this.details);
}

/// Result for QUOTA operations
class QuotaResult {
  String rootName;

  List<ResourceLimit> resourceLimits;

  QuotaResult(this.rootName, this.resourceLimits);
}

/// Result for QUOTAROOT operations
class QuotaRootResult {
  String mailboxName;

  List<String> rootNames;

  Map<String, QuotaResult> quotaRoots = {};

  QuotaRootResult(this.mailboxName, this.rootNames);
}

/// Result for SORT and UID SORT operations
///
/// Copy of [SearchImapResult] class because SEARCH and SORT are equivalents
class SortImapResult {
  /// A list of message IDs
  MessageSequence matchingSequence;

  /// The highest modification sequence in the searched messages
  /// The modification sequeqnce can only be returned when the MODSEQ search criteria has been used and when the server supports the CONDSTORE capability.
  int highestModSequence;

  /// Signals an extended sort result
  bool isExtended;

  /// Result tag
  String tag;

  /// Minimum found message ID or UID
  int min;

  /// Maximum found message ID or UID
  int max;

  /// Matches count
  int count;
}
