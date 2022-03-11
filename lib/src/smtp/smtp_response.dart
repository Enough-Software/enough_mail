/// Basic type of a SMTP response
enum SmtpResponseType {
  /// The request has been accepted
  accepted,

  /// The request has been successfully processed
  success,

  /// The server requires information before proceeding
  needInfo,

  /// The request resulted into an temporary error - try again
  temporaryError,

  /// The request resulted in a permanent error and should not be retried
  fatalError,

  /// Other response type
  unknown
}

/// Contains a response from the SMTP server
class SmtpResponse {
  /// Creates a new response
  SmtpResponse(List<String> responseTexts) {
    for (final responseText in responseTexts) {
      if (responseText.isNotEmpty) {
        responseLines.add(SmtpResponseLine.parse(responseText));
      }
    }
  }

  /// Individual response lines
  List<SmtpResponseLine> responseLines = <SmtpResponseLine>[];

  /// The (last) response code
  int? get code => responseLines.last.code;

  /// The (last) message
  String? get message => responseLines.last.message;

  /// The (last) response type
  SmtpResponseType get type => responseLines.last.type;

  /// Checks if the request succeeded
  bool get isOkStatus => type == SmtpResponseType.success;

  /// Checks if the request failed
  bool get isFailedStatus => !(isOkStatus || type == SmtpResponseType.accepted);

  /// Retrieves the error message
  String get errorMessage {
    final buffer = StringBuffer();
    var appendLineBreak = false;
    for (final line in responseLines) {
      if (line.isFailedStatus) {
        if (appendLineBreak) {
          buffer.write('\n');
        }
        buffer.write(line.message);
        appendLineBreak = true;
      }
    }
    return buffer.toString();
  }
}

/// Contains a single SMTP response line
class SmtpResponseLine {
  /// Creates a new response line
  const SmtpResponseLine(this.code, this.message);

  /// Parses the given response [text].
  factory SmtpResponseLine.parse(String text) {
    final code = int.tryParse(text.substring(0, 3));
    final message = (code == null) ? text : text.substring(4);
    return SmtpResponseLine(code ?? 500, message);
  }

  /// The code of the response
  final int code;

  /// The message of the response
  final String message;

  /// The type of the response
  SmtpResponseType get type {
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

  /// Checks if the request failed
  bool get isFailedStatus {
    final t = type;
    return !(t == SmtpResponseType.accepted || t == SmtpResponseType.success);
  }
}
