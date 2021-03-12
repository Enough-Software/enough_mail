import 'dart:typed_data';

import 'package:enough_mail/src/util/uint8_list_reader.dart';

import 'imap_response.dart';
import 'imap_response_line.dart';

class ImapResponseReader {
  final Function(ImapResponse) onImapResponse;
  final Uint8ListReader _rawReader = Uint8ListReader();
  ImapResponse? _currentResponse;
  ImapResponseLine? _currentLine;

  ImapResponseReader(this.onImapResponse);

  void onData(Uint8List data) {
    _rawReader.add(data);
    // var text = String.fromCharCodes(data).replaceAll('\r\n', '<CRLF>\n');
    // print('onData: $text');
    //  print("onData: hasLineBreak=${_rawReader.hasLineBreak()} currentResponse != null: ${(_currentResponse != null)}");
    if (_currentResponse != null) {
      _checkResponse(_currentResponse!, _currentLine!);
    }
    if (_currentResponse == null) {
      // there is currently no response awaiting its finalization
      var text = _rawReader.readLine();
      while (text != null) {
        var response = ImapResponse();
        var line = ImapResponseLine(text);
        response.add(line);
        if (line.isWithLiteral) {
          _currentLine = line;
          _currentResponse = response;
          _checkResponse(response, line);
        } else {
          // this is a simple response:
          onImapResponse(response);
        }
        if (_currentLine != null && _currentLine!.isWithLiteral) {
          break;
        }
        text = _rawReader.readLine();
      }
    }
  }

  void _checkResponse(ImapResponse response, ImapResponseLine line) {
    if (line.isWithLiteral) {
      if (_rawReader.isAvailable(line.literal!)) {
        var rawLine = ImapResponseLine.raw(_rawReader.readBytes(line.literal!));
        response.add(rawLine);
        _currentLine = rawLine;
        _checkResponse(response, rawLine);
      }
    } else {
      // current line has no literal
      var text = _rawReader.readLine();
      if (text != null) {
        var textLine = ImapResponseLine(text);
        // handle special case:
        // the remainder of this line may consists of only a literal,
        // in this case the information should be added on the previous line
        if (textLine.isWithLiteral && textLine.line!.isEmpty) {
          line.literal = textLine.literal;
        } else {
          if (textLine.line!.isNotEmpty) {
            response.add(textLine);
          }
          if (!textLine.isWithLiteral) {
            // this is the last line of this server response:
            onImapResponse(response);
            _currentResponse = null;
            _currentLine = null;
          } else {
            _currentLine = textLine;
            _checkResponse(response, textLine);
          }
        }
      }
    }
  }
}
