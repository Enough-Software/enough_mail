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
