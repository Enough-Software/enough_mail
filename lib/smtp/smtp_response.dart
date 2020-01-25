enum SmtpResponseType {
  accepted,
  success,
  needInfo,
  temporaryError,
  fatalError,
  unknown
}

class SmtpResponse {
  List<SmtpResponseLine> responseLines = <SmtpResponseLine>[];
  int get code => responseLines.last.code;
  String get message => responseLines.last.message;
  SmtpResponseType get type => responseLines.last.type;
  bool get isOkStatus => type == SmtpResponseType.success;
  bool get isFailedStatus => !(isOkStatus || type == SmtpResponseType.accepted);

  SmtpResponse(List<String> responseTexts) {
    for (var responseText in responseTexts) {
      if (responseText.isNotEmpty) {
        responseLines.add(SmtpResponseLine(responseText));
      }
    }
  }
}

class SmtpResponseLine {
  int code;
  String message;
  SmtpResponseType get type => _getType();

  SmtpResponseLine(String responseText) {
    code = int.tryParse(responseText.substring(0, 3));
    if (code == null) {
      message = responseText;
    } else {
      message = responseText.substring(4);
    }
  }

  SmtpResponseType _getType() {
    SmtpResponseType type;
    switch (code ~/ 100) {
      case 1:
        type = SmtpResponseType.accepted;
        break;
      case 2:
        type = SmtpResponseType.success;
        break;
      case 3:
        type = SmtpResponseType.needInfo;
        break;
      case 4:
        type = SmtpResponseType.temporaryError;
        break;
      case 5:
        type = SmtpResponseType.fatalError;
        break;

      default:
        type = SmtpResponseType.unknown;
    }
    return type;
  }
}
