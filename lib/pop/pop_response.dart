class PopResponse<T> {
  bool isOkStatus;
  bool get isFailedStatus => !isOkStatus;
  T result;

  PopResponse();
}

class PopStatus {
  int numberOfMessages;
  int totalSizeInBytes;
}

class MessageListing {
  int id;
  String uid;
  int sizeInBytes;
}

class PopServerInfo {
  String timestamp;
}
