import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/response.dart';

class MailResponse<T> {
  T result;
  bool isOkStatus;
  bool get isFailedStatus => !isOkStatus;
  String errorId;
}

class MailResponseHelper {
  static MailResponse<T> createFromImap<T>(Response<T> imap) {
    return MailResponse<T>()
      ..isOkStatus = imap.isOkStatus
      ..result = imap.result;
  }

  static MailResponse<T> createFromPop<T>(PopResponse popResponse) {
    return MailResponse<T>()
      ..isOkStatus = popResponse.isOkStatus
      ..result = popResponse.result;
  }

  static MailResponse<T> success<T>(T result) {
    return MailResponse<T>()
      ..result = result
      ..isOkStatus = true;
  }

  static MailResponse<T> failure<T>(String errorId) {
    return MailResponse<T>()
      ..errorId
      ..isOkStatus = false;
  }
}
