import 'dart:convert';
import 'dart:typed_data';

import '../../../mail_address.dart';
import '../../../mime_data.dart';
import '../../../mime_message.dart';
import '../../../smtp/smtp_response.dart';
import '../smtp_command.dart';

enum _BdatSequence { mailFrom, rcptTo, bdat, done }

class _SmtpSendBdatCommand extends SmtpCommand {
  _SmtpSendBdatCommand(
    this.getData,
    this.fromEmail,
    this.recipientEmails, {
    required this.use8BitEncoding,
  }) : super('MAIL FROM') {
    final binaryData = _codec.encode(getData());
    _chunks = chunkData(binaryData);
  }

  final String Function() getData;
  final String? fromEmail;
  final List<String> recipientEmails;
  final bool use8BitEncoding;
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
      final bdat = _codec.encode(isLast
          ? 'BDAT ${sublist.length} LAST\r\n'
          : 'BDAT ${sublist.length}\r\n');
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
    if (use8BitEncoding) {
      return 'MAIL FROM:<$fromEmail> BODY=8BITMIME';
    }
    return 'MAIL FROM:<$fromEmail>';
  }

  @override
  SmtpCommandData? next(SmtpResponse response) {
    final step = _currentStep;
    switch (step) {
      case _BdatSequence.mailFrom:
        _currentStep = _BdatSequence.rcptTo;
        _recipientIndex++;
        return SmtpCommandData(
            _getRecipientToCommand(recipientEmails[0]), null);
      case _BdatSequence.rcptTo:
        final index = _recipientIndex;
        if (index < recipientEmails.length) {
          _recipientIndex++;
          return SmtpCommandData(
              _getRecipientToCommand(recipientEmails[index]), null);
        } else if (response.type == SmtpResponseType.success) {
          return _getCurrentChunk();
        } else {
          return null;
        }
      case _BdatSequence.bdat:
        return _getCurrentChunk();
      default:
        return null;
    }
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
  bool isCommandDone(SmtpResponse response) {
    if (_currentStep == _BdatSequence.bdat) {
      return response.code == 354;
    }
    return (response.type != SmtpResponseType.success) ||
        (_currentStep == _BdatSequence.done);
  }
}

/// Sends a message using BDAT
class SmtpSendBdatMailCommand extends _SmtpSendBdatCommand {
  /// Creates a new BDAT command
  SmtpSendBdatMailCommand(
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

/// Sends a MIME Data via BDAT
class SmtpSendBdatMailDataCommand extends _SmtpSendBdatCommand {
  /// Creates a new BDAT command
  SmtpSendBdatMailDataCommand(
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

/// Sends message text via BDAT
class SmtpSendBdatMailTextCommand extends _SmtpSendBdatCommand {
  /// Creates a new BDAT command
  SmtpSendBdatMailTextCommand(
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

  /// The message text data
  final String data;
}
