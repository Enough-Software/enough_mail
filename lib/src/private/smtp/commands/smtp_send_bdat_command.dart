import 'dart:convert';
import 'dart:typed_data';

import '../../../mail_address.dart';
import '../../../mime_data.dart';
import '../../../mime_message.dart';
import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

enum _BdatSequence { mailFrom, rcptTo, bdat, done, failed }

class _SmtpSendBdatCommand extends SmtpCommand {
  _SmtpSendBdatCommand(
    this.getData,
    String? fromEmail,
    List<String> recipientEmails, {
    required this.use8BitEncoding,
    required this.supportUnicode,
  }) : fromEmail = validateEnvelopeAddress(fromEmail, 'from'),
       recipientEmails = [
         for (final recipient in recipientEmails)
           validateEnvelopeAddress(recipient, 'recipient'),
       ],
       super('MAIL FROM') {
    if (recipientEmails.isEmpty) {
      throw ArgumentError.value(recipientEmails, 'recipients', 'no recipients');
    }
    final binaryData = _codec.encode(getData());
    _chunks = chunkData(binaryData);
  }

  final String Function() getData;
  final String fromEmail;
  final List<String> recipientEmails;
  final bool use8BitEncoding;
  final bool supportUnicode;
  _BdatSequence _currentStep = _BdatSequence.mailFrom;
  int _recipientIndex = 0;
  late List<Uint8List> _chunks;
  int _chunkIndex = 0;
  static const Utf8Codec _codec = Utf8Codec(allowMalformed: true);

  static List<Uint8List> chunkData(List<int> binaryData) {
    const chunkSize = 512 * 1024;
    final result = <Uint8List>[];
    var startIndex = 0;
    final length = binaryData.length;
    while (startIndex < length) {
      final isLast = startIndex + chunkSize >= length;
      final endIndex = isLast ? length : startIndex + chunkSize;
      final sublist = binaryData.sublist(startIndex, endIndex);
      final bdat = _codec.encode(
        isLast
            ? 'BDAT ${sublist.length} LAST\r\n'
            : 'BDAT ${sublist.length}\r\n',
      );
      // combine both:
      final chunkData = Uint8List(bdat.length + sublist.length)
        ..setRange(0, bdat.length, bdat)
        ..setRange(bdat.length, bdat.length + sublist.length, sublist);
      result.add(chunkData);
      startIndex += chunkSize;
    }

    return result;
  }

  @override
  String get command {
    // cSpell:ignore SMTPUTF8
    final parameters = [
      if (use8BitEncoding) 'BODY=8BITMIME',
      if (supportUnicode) 'SMTPUTF8',
    ];

    return parameters.isEmpty
        ? 'MAIL FROM:<$fromEmail>'
        : 'MAIL FROM:<$fromEmail> ${parameters.join(' ')}';
  }

  @override
  SmtpCommandData? next(SmtpResponse response) {
    switch (_currentStep) {
      case _BdatSequence.mailFrom:
        if (response.type != SmtpResponseType.success) {
          _currentStep = _BdatSequence.failed;

          return null;
        }
        _currentStep = _BdatSequence.rcptTo;
        _recipientIndex = 1;

        return SmtpCommandData(
          _getRecipientToCommand(recipientEmails[0]),
          null,
        );
      case _BdatSequence.rcptTo:
        if (response.type != SmtpResponseType.success) {
          failureResponse ??= response;
        }
        final index = _recipientIndex;
        if (index < recipientEmails.length) {
          _recipientIndex++;

          return SmtpCommandData(
            _getRecipientToCommand(recipientEmails[index]),
            null,
          );
        }
        if (failureResponse != null) {
          return _abort();
        }
        _currentStep = _BdatSequence.bdat;

        return _getCurrentChunk();
      case _BdatSequence.bdat:
        if (response.type != SmtpResponseType.success) {
          // RFC 3030: every chunk is acknowledged with a 250 reply
          failureResponse = response;

          return _abort();
        }

        return _getCurrentChunk();
      case _BdatSequence.done:
      case _BdatSequence.failed:
        return null;
    }
  }

  /// Aborts the mail transaction so that the connection can be reused
  SmtpCommandData _abort() {
    _currentStep = _BdatSequence.failed;

    return SmtpCommandData('RSET', null);
  }

  SmtpCommandData _getCurrentChunk() {
    final chunk = _chunks[_chunkIndex];
    _chunkIndex++;
    if (_chunkIndex >= _chunks.length) {
      _currentStep = _BdatSequence.done;
    }

    return SmtpCommandData(null, chunk);
  }

  String _getRecipientToCommand(String email) => 'RCPT TO:<$email>';

  @override
  bool isCommandDone(SmtpResponse response) =>
      _currentStep == _BdatSequence.done ||
      _currentStep == _BdatSequence.failed;
}

/// Sends a message using BDAT
class SmtpSendBdatMailCommand extends _SmtpSendBdatCommand {
  /// Creates a new BDAT command
  SmtpSendBdatMailCommand(
    this.message,
    MailAddress? from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
    required bool supportUnicode,
  }) : super(
         () => removeBccHeader(message.renderMessage()),
         from?.email ?? message.fromEmail,
         recipientEmails,
         use8BitEncoding: use8BitEncoding,
         supportUnicode: supportUnicode,
       );

  /// The message to be sent
  final MimeMessage message;
}

/// Sends a MIME Data via BDAT
class SmtpSendBdatMailDataCommand extends _SmtpSendBdatCommand {
  /// Creates a new BDAT command
  SmtpSendBdatMailDataCommand(
    this.data,
    MailAddress from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
    required bool supportUnicode,
  }) : super(
         () => removeBccHeader(data.toString()),
         from.email,
         recipientEmails,
         use8BitEncoding: use8BitEncoding,
         supportUnicode: supportUnicode,
       );

  /// The message data to be sent
  final MimeData data;
}

/// Sends message text via BDAT
class SmtpSendBdatMailTextCommand extends _SmtpSendBdatCommand {
  /// Creates a new BDAT command
  SmtpSendBdatMailTextCommand(
    this.data,
    MailAddress from,
    List<String> recipientEmails, {
    required bool use8BitEncoding,
    required bool supportUnicode,
  }) : super(
         () => data,
         from.email,
         recipientEmails,
         use8BitEncoding: use8BitEncoding,
         supportUnicode: supportUnicode,
       );

  /// The message text data
  final String data;
}
