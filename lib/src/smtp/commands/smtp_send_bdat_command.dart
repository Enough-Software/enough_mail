import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/smtp/smtp_response.dart';
import 'package:enough_mail/src/smtp/smtp_command.dart';

enum _BdatSequence { mailFrom, rcptTo, bdat, done }

class _SmtpSendBdatCommand extends SmtpCommand {
  final String Function() getData;
  final String fromEmail;
  final List<String> recipientEmails;
  final bool use8BitEncoding;
  _BdatSequence _currentStep = _BdatSequence.mailFrom;
  int _recipientIndex = 0;
  List<Uint8List> _chunks;
  int _chunkIndex = 0;
  static const Utf8Codec _codec = Utf8Codec(allowMalformed: true);

  _SmtpSendBdatCommand(
      this.getData, this.use8BitEncoding, this.fromEmail, this.recipientEmails)
      : super('MAIL FROM') {
    final binaryData = _codec.encode(getData());
    _chunks = chunkData(binaryData);
  }

  static List<Uint8List> chunkData(List<int> binaryData) {
    final chunkSize = 512 * 1024;
    final result = <Uint8List>[];
    var startIndex = 0;
    final length = binaryData.length;
    while (startIndex < length) {
      final isLast = (startIndex + chunkSize >= length);
      final endIndex = isLast ? length : startIndex + chunkSize;
      final sublist = binaryData.sublist(startIndex, endIndex);
      final bdat = _codec.encode(isLast
          ? 'BDAT ${sublist.length} LAST\r\n'
          : 'BDAT ${sublist.length}\r\n');
      // combine both:
      final chunkData = Uint8List(bdat.length + sublist.length);
      chunkData.setRange(0, bdat.length, bdat);
      chunkData.setRange(bdat.length, bdat.length + sublist.length, sublist);
      result.add(chunkData);
      startIndex += chunkSize;
    }
    return result;
  }

  @override
  String getCommand() {
    if (use8BitEncoding) {
      return 'MAIL FROM:<${fromEmail}> BODY=8BITMIME';
    }
    return 'MAIL FROM:<${fromEmail}>';
  }

  @override
  SmtpCommandData next(SmtpResponse response) {
    var step = _currentStep;
    switch (step) {
      case _BdatSequence.mailFrom:
        _currentStep = _BdatSequence.rcptTo;
        _recipientIndex++;
        return SmtpCommandData(
            _getRecipientToCommand(recipientEmails[0]), null);
        break;
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
        break;
      case _BdatSequence.bdat:
        return _getCurrentChunk();
        break;
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

  String _getRecipientToCommand(String email) {
    return 'RCPT TO:<$email>';
  }

  @override
  bool isCommandDone(SmtpResponse response) {
    if (_currentStep == _BdatSequence.bdat) {
      return (response.code == 354);
    }
    return (response.type != SmtpResponseType.success) ||
        (_currentStep == _BdatSequence.done);
  }
}

class SmtpSendBdatMailCommand extends _SmtpSendBdatCommand {
  final MimeMessage message;

  SmtpSendBdatMailCommand(this.message, bool use8BitEncoding, MailAddress from)
      : super(
            () => message
                .renderMessage()
                .replaceAll(RegExp('^Bcc:.*\r\n', multiLine: true), ''),
            use8BitEncoding,
            from?.email ?? message.fromEmail,
            message.recipientAddresses);
}

class SmtpSendBdatMailDataCommand extends _SmtpSendBdatCommand {
  final MimeData data;

  SmtpSendBdatMailDataCommand(this.data, bool use8BitEncoding, MailAddress from,
      List<String> recipientEmails)
      : super(
            () => data
                .toString()
                .replaceAll(RegExp('^Bcc:.*\r\n', multiLine: true), ''),
            use8BitEncoding,
            from.email,
            recipientEmails);
}

class SmtpSendBdatMailTextCommand extends _SmtpSendBdatCommand {
  final String data;

  SmtpSendBdatMailTextCommand(this.data, bool use8BitEncoding, MailAddress from,
      List<String> recipientEmails)
      : super(() => data, use8BitEncoding, from.email, recipientEmails);
}
