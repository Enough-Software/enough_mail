import '../../../../enough_mail.dart';
import '../smtp_command.dart';

enum _SmtpSendCommandSequence { mailFrom, rcptTo, data, done }

class _SmtpSendCommand extends SmtpCommand {
  _SmtpSendCommand(
    this.getData,
    this.fromEmail,
    this.recipientEmails, {
    required this.use8BitEncoding,
  }) : super('MAIL FROM');

  final String Function() getData;
  final String? fromEmail;
  final List<String> recipientEmails;
  final bool use8BitEncoding;
  _SmtpSendCommandSequence _currentStep = _SmtpSendCommandSequence.mailFrom;
  int _recipientIndex = 0;

  @override
  String get command {
    if (use8BitEncoding) {
      return 'MAIL FROM:<$fromEmail> BODY=8BITMIME';
    }
    return 'MAIL FROM:<$fromEmail>';
  }

  @override
  String? nextCommand(SmtpResponse response) {
    final step = _currentStep;
    switch (step) {
      case _SmtpSendCommandSequence.mailFrom:
        _currentStep = _SmtpSendCommandSequence.rcptTo;
        _recipientIndex++;
        return _getRecipientToCommand(recipientEmails[0]);
      case _SmtpSendCommandSequence.rcptTo:
        final index = _recipientIndex;
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
        return '${data.replaceAll('\r\n.\r\n', '\r\n..\r\n')}\r\n.';
      default:
        return null;
    }
  }

  String _getRecipientToCommand(String email) => 'RCPT TO:<$email>';

  @override
  bool isCommandDone(SmtpResponse response) {
    if (_currentStep == _SmtpSendCommandSequence.data) {
      return response.code == 354;
    }
    return (response.type != SmtpResponseType.success) ||
        (_currentStep == _SmtpSendCommandSequence.done);
  }
}

/// Sends a MIME message
class SmtpSendMailCommand extends _SmtpSendCommand {
  /// Creates a new DATA command
  SmtpSendMailCommand(
    this.message,
    MailAddress? from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
  }) : super(
          () => message
              .renderMessage()
              .replaceAll(RegExp('^Bcc:.*\r\n', multiLine: true), ''),
          from?.email ?? message.fromEmail,
          recipientEmails,
          use8BitEncoding: use8BitEncoding,
        );

  /// The message to be sent
  final MimeMessage message;
}

/// Sends the message data
class SmtpSendMailDataCommand extends _SmtpSendCommand {
  /// Creates a new DATA command
  SmtpSendMailDataCommand(
    this.data,
    MailAddress from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
  }) : super(
          () => data
              .toString()
              .replaceAll(RegExp('^Bcc:.*\r\n', multiLine: true), ''),
          from.email,
          recipientEmails,
          use8BitEncoding: use8BitEncoding,
        );

  /// The message data to be sent
  final MimeData data;
}

/// Sends textual message data
class SmtpSendMailTextCommand extends _SmtpSendCommand {
  /// Creates a new DATA command
  SmtpSendMailTextCommand(
    this.data,
    MailAddress from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
  }) : super(
          () => data,
          from.email,
          recipientEmails,
          use8BitEncoding: use8BitEncoding,
        );

  /// The message text data to be sent
  final String data;
}
