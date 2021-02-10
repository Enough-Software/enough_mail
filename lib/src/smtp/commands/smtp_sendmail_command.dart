import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/smtp/smtp_response.dart';
import 'package:enough_mail/src/smtp/smtp_command.dart';

enum SmtpSendCommandSequence { mailFrom, rcptTo, data, done }

class SmtpSendMailCommand extends SmtpCommand {
  final MimeMessage _message;
  final bool _use8BitEncoding;
  final MailAddress from;
  SmtpSendCommandSequence _currentStep = SmtpSendCommandSequence.mailFrom;
  int _recipientIndex = 0;

  List<String> _recipientAddresses;

  SmtpSendMailCommand(this._message, this._use8BitEncoding, this.from)
      : super('MAIL FROM');

  @override
  String getCommand() {
    final email = from?.email ?? _message.fromEmail;
    if (_use8BitEncoding) {
      return 'MAIL FROM:<${email}> BODY=8BITMIME';
    }
    return 'MAIL FROM:<${email}>';
  }

  @override
  String nextCommand(SmtpResponse response) {
    var step = _currentStep;
    switch (step) {
      case SmtpSendCommandSequence.mailFrom:
        _currentStep = SmtpSendCommandSequence.rcptTo;
        _recipientIndex++;
        _recipientAddresses = _message.recipientAddresses;
        if (_recipientAddresses == null || _recipientAddresses.isEmpty) {
          throw StateError('No recipients defined in message.');
        }
        return _getRecipientToCommand(_recipientAddresses[0]);
        break;
      case SmtpSendCommandSequence.rcptTo:
        var index = _recipientIndex;
        if (index < _recipientAddresses.length) {
          _recipientIndex++;
          return _getRecipientToCommand(_recipientAddresses[index]);
        } else if (response.type == SmtpResponseType.success) {
          _currentStep = SmtpSendCommandSequence.data;
          return 'DATA';
        } else {
          return null;
        }
        break;
      case SmtpSendCommandSequence.data:
        _currentStep = SmtpSendCommandSequence.done;

        // Build the message but strip the bcc header
        var data = _message.renderMessage().replaceAll(
          RegExp('^Bcc:.*\r\n', multiLine: true), ''
        );

        // \r\n.\r\n is the data stop sequence, so 'pad' this sequence in the message data
        return data.replaceAll('\r\n.\r\n', '\r\n..\r\n') + '\r\n.';
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
