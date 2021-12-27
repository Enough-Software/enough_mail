/// Provides access to a POP response coming from the POP service
class PopResponse<T> {
  /// Creates a new response
  PopResponse({this.isOkStatus = false, this.result});

  /// Is the response indicating success?
  bool isOkStatus;

  /// Is this is failed response?
  bool get isFailedStatus => !isOkStatus;

  /// The result of the response
  T? result;
}

/// Provides status information about a POP service
class PopStatus {
  /// Creates a new status
  PopStatus(this.numberOfMessages, this.totalSizeInBytes);

  /// The number of available messages
  final int numberOfMessages;

  /// The total used size in bytes
  final int totalSizeInBytes;
}

/// Basic information about a message
class MessageListing {
  /// Creates a new listing
  MessageListing({
    required this.id,
    required this.sizeInBytes,
    this.uid,
  });

  /// The message ID
  final int id;

  /// The message UID
  final String? uid;

  /// The message size in bytes
  final int sizeInBytes;
}

/// The server information
class PopServerInfo {
  /// Creates a new server info instance
  PopServerInfo(this.timestamp);

  /// The timestamp value
  final String timestamp;
}
