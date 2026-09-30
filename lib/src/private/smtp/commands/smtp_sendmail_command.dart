import '../../../../enough_mail.dart';
import '../smtp_command.dart';

enum _SmtpSendCommandSequence { mailFrom, rcptTo, data, done, failed }

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
    switch (_currentStep) {
      case _SmtpSendCommandSequence.mailFrom:
        if (response.type != SmtpResponseType.success) {
          // no transaction was started, nothing to reset
          _currentStep = _SmtpSendCommandSequence.failed;

          return null;
        }
        _currentStep = _SmtpSendCommandSequence.rcptTo;
        _recipientIndex = 1;

        return _getRecipientToCommand(recipientEmails[0]);
      case _SmtpSendCommandSequence.rcptTo:
        if (response.type != SmtpResponseType.success) {
          // remember the first rejected recipient, but let the server see
          // all recipients before aborting the transaction
          failureResponse ??= response;
        }
        final index = _recipientIndex;
        if (index < recipientEmails.length) {
          _recipientIndex++;

          return _getRecipientToCommand(recipientEmails[index]);
        }
        if (failureResponse != null) {
          return _abort();
        }
        _currentStep = _SmtpSendCommandSequence.data;

        return 'DATA';
      case _SmtpSendCommandSequence.data:
        if (response.code != 354) {
          // the server does not want the message data
          failureResponse = response;

          return _abort();
        }
        _currentStep = _SmtpSendCommandSequence.done;

        return applySmtpTransparency(getData());
      case _SmtpSendCommandSequence.done:
      case _SmtpSendCommandSequence.failed:
        return null;
    }
  }

  /// Aborts the mail transaction so that the connection can be reused
  String _abort() {
    _currentStep = _SmtpSendCommandSequence.failed;

    return 'RSET';
  }

  String _getRecipientToCommand(String email) => 'RCPT TO:<$email>';

  @override
  bool isCommandDone(SmtpResponse response) =>
      _currentStep == _SmtpSendCommandSequence.done ||
      _currentStep == _SmtpSendCommandSequence.failed;
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
         () => removeBccHeader(message.renderMessage()),
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
         () => removeBccHeader(data.toString()),
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
