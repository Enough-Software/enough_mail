class PopResponse<T> {
  bool isOkStatus;
  bool get isFailedStatus => !isOkStatus;
  T? result;

  PopResponse({this.isOkStatus = false, this.result});
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
