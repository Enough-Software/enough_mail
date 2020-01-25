import 'package:enough_mail/smtp/smtp_response.dart';

import '../../../enough_mail.dart';
import 'package:enough_mail/src/smtp/smtp_command.dart';

enum SmtpSendCommandSequence { mailFrom, rcptTo, data, done }

class SmtpSendMailCommand extends SmtpCommand {
  final Message _message; 
  final bool _use8BitEncoding;
  SmtpSendCommandSequence _currentStep = SmtpSendCommandSequence.mailFrom;
  int _recipientIndex = 0;

  SmtpSendMailCommand(this._message, this._use8BitEncoding)
      : super('MAIL FROM');

  @override
  String getCommand() {
    if (_use8BitEncoding) {
      return 'MAIL FROM:<${_message.fromEmail}> BODY=8BITMIME';
    }
    return 'MAIL FROM:<${_message.fromEmail}>';
  }

  @override
  String nextCommand(SmtpResponse response) {
    var step = _currentStep;
    switch (step) {
      case SmtpSendCommandSequence.mailFrom:
        if (_message.recipients.isEmpty) {
          return null;
        }
        _currentStep = SmtpSendCommandSequence.rcptTo;
        _recipientIndex++;
        return _getRecipientToCommand(_message.recipients[0]);
        break;
      case SmtpSendCommandSequence.rcptTo:
        var index = _recipientIndex;
        if (index < _message.recipients.length) {
          _recipientIndex++;
          return _getRecipientToCommand(_message.recipients[index]);
        } else if (response.type == SmtpResponseType.success) {
          _currentStep = SmtpSendCommandSequence.data;
          return 'DATA';
        } else {
          return null;
        }
        break;
      case SmtpSendCommandSequence.data:
        _currentStep = SmtpSendCommandSequence.done;
        return _message.headerRaw + '\r\n' + _message.bodyRaw + '\r\n.';
      default:
        return null;
    }
  }

  String _getRecipientToCommand(String email) {
    return 'RCPT TO:<$email>';
  }

  @override
  bool isCommandDone(SmtpResponse response) {
    if (_currentStep == SmtpSendCommandSequence.data) {
      return (response.code == 354);
    }
    return (response.type != SmtpResponseType.success) ||
        (_currentStep == SmtpSendCommandSequence.done);
  }
}
