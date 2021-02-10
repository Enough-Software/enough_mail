import 'dart:typed_data';

import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';

import 'src/util/ascii_runes.dart';

abstract class MimeData {
  final bool containsHeader;
  MimeData(this.containsHeader);

  List<Header> headersList;
  bool get hasParts => parts?.isNotEmpty ?? false;
  List<MimeData> parts;

  ContentTypeHeader _contentType;
  ContentTypeHeader get contentType {
    var value = _contentType;
    if (value == null) {
      final headerText = _getHeaderValue('content-type');
      if (headerText != null) {
        value = ContentTypeHeader(headerText);
      }
    }
    return value;
  }

  bool _isParsed = false;
  ContentTypeHeader _parsingContentTypeHeader;

  String decodeText(
      ContentTypeHeader contentTypeHeader, String contentTransferEncoding);

  Uint8List decodeBinary(String contentTransferEncoding);

  void parse(ContentTypeHeader contentTypeHeader) {
    if (_isParsed && (contentTypeHeader == _parsingContentTypeHeader)) {
      return;
    }
    _isParsed = true;
    _parsingContentTypeHeader = contentTypeHeader;
    _parseContent(contentTypeHeader);
  }

  void _parseContent(ContentTypeHeader contentTypeHeader);

  String render(StringBuffer buffer) {
    buffer ??= StringBuffer();
    // not needed as the data contains the header information as well
    // if (containsHeader) {
    //   for (final header in headersList) {
    //     header.render(buffer);
    //   }
    //   buffer.write('\r\n');
    // }
    _renderContent(buffer);
    return buffer.toString();
  }

  void _renderContent(StringBuffer buffer);

  Header _getHeader(String lowerCaseName) {
    return headersList?.firstWhere((h) => h.lowerCaseName == lowerCaseName,
        orElse: () => null);
  }

  String _getHeaderValue(String lowerCaseName) {
    return _getHeader(lowerCaseName)?.value;
  }
}

class TextMimeData extends MimeData {
  final String text;
  String body;
  TextMimeData(this.text, bool containsHeader) : super(containsHeader);

  @override
  void _parseContent(ContentTypeHeader contentTypeHeader) {
    var bodyText = text;
    if (containsHeader) {
      if (text.startsWith('\r\n')) {
        // this part has no header
        bodyText = text.substring(2);
      } else {
        var headerParseResult = ParserHelper.parseHeader(text);
        if (headerParseResult.bodyStartIndex != null) {
          if (headerParseResult.bodyStartIndex >= text.length) {
            bodyText = '';
          } else {
            bodyText = text.substring(headerParseResult.bodyStartIndex);
          }
        }
        headersList = headerParseResult.headersList;
      }
      contentTypeHeader ??= contentType;
    } else {
      bodyText = text;
    }
    if (contentTypeHeader?.boundary == null) {
      body = bodyText;
    } else {
      parts = [];
      final splitBoundary = '--' + contentTypeHeader.boundary + '\r\n';
      final childParts = bodyText.split(splitBoundary);
      if (!bodyText.startsWith(splitBoundary)) {
        // mime-readers can ignore the preamble:
        childParts.removeAt(0);
      }
      var lastPart = childParts.last;
      final closingIndex =
          lastPart.lastIndexOf('--' + contentTypeHeader.boundary + '--');
      if (closingIndex != -1) {
        childParts.removeLast();
        lastPart = lastPart.substring(0, closingIndex);
        childParts.add(lastPart);
      }
      for (final childPart in childParts) {
        if (childPart.isNotEmpty) {
          var part = TextMimeData(childPart, true);
          part.parse(null);
          parts.add(part);
        }
      }
    }
  }

  @override
  void _renderContent(StringBuffer buffer) {
    buffer.write(text);
  }

  @override
  Uint8List decodeBinary(String contentTransferEncoding) {
    return MailCodec.decodeBinary(body, contentTransferEncoding);
  }

  @override
  String decodeText(
      ContentTypeHeader contentTypeHeader, String contentTransferEncoding) {
    return MailCodec.decodeAnyText(
        body, contentTransferEncoding, contentTypeHeader?.charset);
  }
}

class BinaryMimeData extends MimeData {
  final Uint8List data;
  int _bodyStartIndex;
  Uint8List _bodyData;

  BinaryMimeData(this.data, bool containsHeader) : super(containsHeader);

  @override
  void _parseContent(ContentTypeHeader contentTypeHeader) {
    if (containsHeader) {
      headersList = _parseHeader();
    } else {
      _bodyStartIndex = 0;
    }
    if (_bodyStartIndex != null) {
      _bodyData = _bodyStartIndex == 0 ? data : data.sublist(_bodyStartIndex);
      contentTypeHeader ??= contentType;
      if (contentTypeHeader?.boundary != null &&
          contentTypeHeader.mediaType.isMultipart) {
        // split into different parts:
        parts = _splitAndParse(contentTypeHeader.boundary, _bodyData);
      }
    }
  }

  List<BinaryMimeData> _splitAndParse(
      final String boundaryText, final Uint8List bodyData) {
    final boundary = ('--' + boundaryText + '\r\n').codeUnits;
    final result = <BinaryMimeData>[];
    // end is expected to be \r\n for all but the last one, where -- is expected, possibly followed by \r\n
    int startIndex;
    final maxIndex = bodyData.length - (3 * boundary.length);
    for (var i = 0; i < maxIndex; i++) {
      var foundMatch = true;
      for (var j = 0; j < boundary.length; j++) {
        if (bodyData[i + j] != boundary[j]) {
          foundMatch = false;
          break;
        }
      }
      if (foundMatch) {
        if (startIndex == null) {
          i += boundary.length;
          startIndex = i;
        } else {
          final partData = bodyData.sublist(startIndex, i);
          final part = BinaryMimeData(partData, true);
          part.parse(null);
          result.add(part);
          i += boundary.length;
          startIndex = i;
        }
      }
    }
    // check and add end:
    if (startIndex != null) {
      final endBoundary = ('--' + boundaryText + '--').codeUnits;
      for (var i = bodyData.length - endBoundary.length; i > startIndex; i--) {
        var foundMatch = true;
        for (var j = 0; j < endBoundary.length; j++) {
          if (bodyData[i + j] != endBoundary[j]) {
            foundMatch = false;
            break;
          }
        }
        if (foundMatch) {
          final partData = bodyData.sublist(startIndex, i);
          final part = BinaryMimeData(partData, true);
          part.parse(null);
          result.add(part);
          break;
        }
      }
    }
    return result;
  }

  @override
  String decodeText(
      ContentTypeHeader contentTypeHeader, String contentTransferEncoding) {
    if (_bodyData == null) {
      return null;
    }
    return MailCodec.decodeAsText(
        _bodyData, contentTransferEncoding, contentTypeHeader?.charset);
  }

  @override
  Uint8List decodeBinary(String contentTransferEncoding) {
    if (_bodyData == null) {
      return null;
    }
    // even with a 'binary' content transfer encoding there are \r\n chararacters that need to be handled,
    // so translate to text first
    final dataText = String.fromCharCodes(_bodyData);
    return MailCodec.decodeBinary(dataText, contentTransferEncoding);
  }

  List<Header> _parseHeader() {
    final headerData = data;
    // shortcut for having an empty line at the start:
    if (headerData.length > 1 &&
        headerData[0] == AsciiRunes.runeCarriageReturn &&
        headerData[1] == AsciiRunes.runeLineFeed) {
      _bodyStartIndex = 2;
      return [];
    }
    // check for first CRLF-CRLF sequence:
    for (var i = 0; i < headerData.length - 4; i++) {
      if (headerData[i] == AsciiRunes.runeCarriageReturn &&
          headerData[i + 1] == AsciiRunes.runeLineFeed &&
          headerData[i + 2] == AsciiRunes.runeCarriageReturn &&
          headerData[i + 3] == AsciiRunes.runeLineFeed) {
        final headerLines =
            String.fromCharCodes(headerData, 0, i).split('\r\n');
        _bodyStartIndex = i + 4;
        return parseHeaderLines(headerLines);
      }
    }
    // the whole data is just headers:
    final headerLines = String.fromCharCodes(headerData).split('\r\n');
    return parseHeaderLines(headerLines);
  }

  List<Header> parseHeaderLines(List<String> headerLines) {
    final result = <Header>[];
    var buffer = StringBuffer();
    String lastLine;
    for (final line in headerLines) {
      if (line.startsWith(' ') || (line.startsWith('\t'))) {
        final trimmed = line.trimLeft();
        if (lastLine == null ||
            !lastLine.endsWith('=') ||
            !trimmed.startsWith('=')) {
          buffer.write(' ');
        }
        buffer.write(trimmed);
      } else {
        if (buffer.isNotEmpty) {
          // got a complete line
          _addHeader(result, buffer);
          buffer = StringBuffer();
        }
        buffer.write(line);
      }
      lastLine = line;
    }
    if (buffer.isNotEmpty) {
      // got a complete line
      _addHeader(result, buffer);
    }
    return result;
  }

  void _addHeader(List<Header> result, StringBuffer buffer) {
    final headerText = buffer.toString();
    final colonIndex = headerText.indexOf(':');
    if (colonIndex != -1) {
      final name = headerText.substring(0, colonIndex);
      if (colonIndex + 2 < headerText.length) {
        final value = headerText.substring(colonIndex + 2);
        result.add(Header(name, value));
      } else {
        result.add(Header(name, ''));
      }
    }
  }

  @override
  void _renderContent(StringBuffer buffer) {
    final text = String.fromCharCodes(data);
    buffer.write(text);
  }
}
