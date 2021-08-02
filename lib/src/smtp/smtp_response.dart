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
  int? get code => responseLines.last.code;
  String? get message => responseLines.last.message;
  SmtpResponseType get type => responseLines.last.type;
  bool get isOkStatus => type == SmtpResponseType.success;
  bool get isFailedStatus => !(isOkStatus || type == SmtpResponseType.accepted);
  String get errorMessage {
    final buffer = StringBuffer();
    var appendLineBreak = false;
    for (final line in responseLines) {
      if (line.isFailedStatus && line.message != null) {
        if (appendLineBreak) {
          buffer.write('\n');
        }
        buffer.write(line.message);
        appendLineBreak = true;
      }
    }
    return buffer.toString();
  }

  SmtpResponse(List<String> responseTexts) {
    for (var responseText in responseTexts) {
      if (responseText.isNotEmpty) {
        responseLines.add(SmtpResponseLine(responseText));
      }
    }
  }
}

class SmtpResponseLine {
  int? code;
  String? message;
  SmtpResponseType get type => _getType();
  bool get isFailedStatus {
    final t = type;
    return !(t == SmtpResponseType.accepted || t == SmtpResponseType.success);
  }

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
    switch (code! ~/ 100) {
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
