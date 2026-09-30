import '../../../../enough_mail.dart';
import '../smtp_command.dart';

enum _SmtpSendCommandSequence { mailFrom, rcptTo, data, done }

class _SmtpSendCommand extends SmtpCommand {
  _SmtpSendCommand(
    this.getData,
    String? fromEmail,
    List<String> recipientEmails, {
    required this.use8BitEncoding,
  }) : fromEmail = validateEnvelopeAddress(fromEmail, 'from'),
       recipientEmails = [
         for (final recipient in recipientEmails)
           validateEnvelopeAddress(recipient, 'recipient'),
       ],
       super('MAIL FROM') {
    if (recipientEmails.isEmpty) {
      throw ArgumentError.value(recipientEmails, 'recipients', 'no recipients');
    }
  }

  final String Function() getData;
  final String fromEmail;
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

        return applySmtpTransparency(getData());
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

/// The `Bcc` header line and every folded continuation line under it.
///
/// `Header.render` folds a value longer than
/// `MailConventions.textLineMaxLength` onto `\r\n\t`-prefixed lines, which
/// three or four addresses already do. Matching only the first physical line
/// left the rest of the list in the DATA that every To/Cc recipient received.
final _bccHeader = RegExp(r'^Bcc:.*\r\n(?:[ \t].*\r\n)*', multiLine: true);

/// Sends a MIME message
class SmtpSendMailCommand extends _SmtpSendCommand {
  /// Creates a new DATA command
  SmtpSendMailCommand(
    this.message,
    MailAddress? from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
  }) : super(
         () => message.renderMessage().replaceAll(_bccHeader, ''),
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
         () => data.toString().replaceAll(_bccHeader, ''),
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
