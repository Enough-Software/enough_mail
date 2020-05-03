/// Status for command responses.
enum ResponseStatus { OK, No, Bad }

/// Base class for command responses.
class Response<T> {
  ResponseStatus status;
  String details;
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
      if (uidParts.length == 2) {
        return UidResponseCode(int.parse(uidParts[0]), int.parse(uidParts[1]));
      }
    }
    return null;
  }
}

class UidResponseCode {
  int uidValidity;
  int uid;
  UidResponseCode(this.uidValidity, this.uid);
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
