import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/smtp/smtp_response.dart';
import 'package:enough_mail/src/smtp/smtp_command.dart';

enum _SmtpSendCommandSequence { mailFrom, rcptTo, data, done }

class _SmtpSendCommand extends SmtpCommand {
  final String Function() getData;
  final String? fromEmail;
  final List<String> recipientEmails;
  final bool use8BitEncoding;
  _SmtpSendCommandSequence _currentStep = _SmtpSendCommandSequence.mailFrom;
  int _recipientIndex = 0;

  _SmtpSendCommand(
      this.getData, this.use8BitEncoding, this.fromEmail, this.recipientEmails)
      : super('MAIL FROM');

  @override
  String getCommand() {
    if (use8BitEncoding) {
      return 'MAIL FROM:<$fromEmail> BODY=8BITMIME';
    }
    return 'MAIL FROM:<$fromEmail>';
  }

  @override
  String? nextCommand(SmtpResponse response) {
    var step = _currentStep;
    switch (step) {
      case _SmtpSendCommandSequence.mailFrom:
        _currentStep = _SmtpSendCommandSequence.rcptTo;
        _recipientIndex++;
        return _getRecipientToCommand(recipientEmails[0]);
      case _SmtpSendCommandSequence.rcptTo:
        var index = _recipientIndex;
        if (index < recipientEmails.length) {
          _recipientIndex++;
          return _getRecipientToCommand(recipientEmails[index]);
        } else if (response.type == SmtpResponseType.success) {
          _currentStep = _SmtpSendCommandSequence.data;
          return 'DATA';
        } else {
          return null;
        }
      case _SmtpSendCommandSequence.data:
        _currentStep = _SmtpSendCommandSequence.done;

        final data = getData();

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
    if (_currentStep == _SmtpSendCommandSequence.data) {
      return (response.code == 354);
    }
    return (response.type != SmtpResponseType.success) ||
        (_currentStep == _SmtpSendCommandSequence.done);
  }
}

class SmtpSendMailCommand extends _SmtpSendCommand {
  final MimeMessage message;

  SmtpSendMailCommand(this.message, bool use8BitEncoding, MailAddress? from,
      List<String> recipientEmails)
      : super(
            () => message
                .renderMessage()
                .replaceAll(RegExp('^Bcc:.*\r\n', multiLine: true), ''),
            use8BitEncoding,
            from?.email ?? message.fromEmail,
            recipientEmails);
}

class SmtpSendMailDataCommand extends _SmtpSendCommand {
  final MimeData data;

  SmtpSendMailDataCommand(this.data, bool use8BitEncoding, MailAddress from,
      List<String> recipientEmails)
      : super(
            () => data
                .toString()
                .replaceAll(RegExp('^Bcc:.*\r\n', multiLine: true), ''),
            use8BitEncoding,
            from.email,
            recipientEmails);
}

class SmtpSendMailTextCommand extends _SmtpSendCommand {
  final String data;

  SmtpSendMailTextCommand(this.data, bool use8BitEncoding, MailAddress from,
      List<String> recipientEmails)
      : super(() => data, use8BitEncoding, from.email, recipientEmails);
}
