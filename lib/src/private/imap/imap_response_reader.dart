import 'dart:typed_data';

import '../util/uint8_list_reader.dart';
import 'imap_response.dart';
import 'imap_response_line.dart';

/// Reads IMAP responses
class ImapResponseReader {
  /// Creates a new imap response reader
  ImapResponseReader(
    this.onImapResponse, {
    this.maxLiteralSize = defaultMaxLiteralSize,
  });

  /// The default for [maxLiteralSize]: 128 MiB
  static const int defaultMaxLiteralSize = 128 * 1024 * 1024;

  /// Callback for finished IMAP responses
  final Function(ImapResponse) onImapResponse;

  /// The maximum accepted size of a single literal in bytes.
  ///
  /// A malicious or broken server could otherwise announce an arbitrarily
  /// large literal and make the client buffer everything that follows
  /// forever. Exceeding the limit throws a [FormatException] from [onData].
  final int maxLiteralSize;

  final Uint8ListReader _rawReader = Uint8ListReader();

  /// The response that is currently being assembled
  ImapResponse? _currentResponse;

  /// The line whose literal data has not been received completely yet
  ImapResponseLine? _awaitingLiteralFor;

  /// Processes the given [data]
  void onData(Uint8List data) {
    _rawReader.add(data);
    _process();
  }

  void _process() {
    while (true) {
      final response = _currentResponse;
      if (response == null) {
        // there is currently no response awaiting its finalization
        final text = _rawReader.readLine();
        if (text == null) {
          return;
        }
        final line = ImapResponseLine(text);
        final newResponse = ImapResponse()..add(line);
        if (line.isWithLiteral) {
          _currentResponse = newResponse;
          _awaitingLiteralFor = line;
          continue;
        }
        // this is a simple response:
        onImapResponse(newResponse);
        continue;
      }
      final awaiting = _awaitingLiteralFor;
      if (awaiting != null) {
        final literal = awaiting.literal ?? 0;
        if (literal > maxLiteralSize) {
          _currentResponse = null;
          _awaitingLiteralFor = null;
          throw FormatException(
            'literal of $literal bytes exceeds the maximum of '
            '$maxLiteralSize bytes',
          );
        }
        final rawData = _rawReader.readBytes(literal);
        if (rawData == null) {
          // wait for more data
          return;
        }
        // an empty literal ({0}) still adds an (empty) data line, so that
        // the remainder of the response is not mistaken for literal data
        response.add(ImapResponseLine.raw(rawData));
        _awaitingLiteralFor = null;
        continue;
      }
      // the literal has been consumed, read the remainder of the line:
      final text = _rawReader.readLine();
      if (text == null) {
        return;
      }
      final textLine = ImapResponseLine(text);
      if (textLine.isWithLiteral && (textLine.line?.isEmpty ?? true)) {
        // the remainder of this line consists of only a literal,
        // in this case the information is added to the previous line
        final previous = response.lines.last..literal = textLine.literal;
        _awaitingLiteralFor = previous;
        continue;
      }
      if (textLine.line?.isNotEmpty ?? false) {
        response.add(textLine);
      }
      if (textLine.isWithLiteral) {
        _awaitingLiteralFor = textLine;
        continue;
      }
      // this is the last line of this server response:
      _currentResponse = null;
      onImapResponse(response);
    }
  }
}
