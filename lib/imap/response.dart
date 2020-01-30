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
