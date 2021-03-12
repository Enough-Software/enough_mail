class PopResponse<T> {
  late bool isOkStatus;
  bool get isFailedStatus => !isOkStatus;
  T? result;

  PopResponse();
}

class PopStatus {
  final int numberOfMessages;
  final int totalSizeInBytes;

  PopStatus(this.numberOfMessages, this.totalSizeInBytes);
}

class MessageListing {
  int? id;
  String? uid;
  int? sizeInBytes;
}

class PopServerInfo {
  late String timestamp;
}
