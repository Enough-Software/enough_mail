import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/util/mail_address_parser.dart';
import 'encodings.dart';

/// Common flags for messages
enum MessageFlag { answered, flagged, deleted, seen, draft }

/// A MIME part
/// In a simple case a MIME message only has one MIME part.
class MimePart {
  List<Header> headers;
  String _headerRaw;
  String get headerRaw => _getHeaderRaw();
  set headerRaw(String headerRaw) => _headerRaw = headerRaw;

  String bodyRaw;
  String text;
  List<MimePart> parts;
  ContentTypeHeader _contentTypeHeader;

  /// Retrieves the raw value of the first matching header.
  ///
  /// Some headers may contain encoded values such as '=?utf-8?B?<data>?='.
  /// Compare [decodeHeaderValue] for retrieving the header value in decoded form.
  /// Compare [getHeader] for retrieving the full header with the given name.
  String getHeaderValue(String name) {
    var headers = getHeader(name.toLowerCase());
    if (headers == null || headers.isEmpty) {
      return null;
    }
    return headers.first.value;
  }

  Iterable<Header> getHeader(String name) =>
      _getHeaderLowercase(name.toLowerCase());

  Iterable<Header> _getHeaderLowercase(String name) =>
      headers?.where((h) => h.name.toLowerCase() == name);

  void addHeader(String name, String value) {
    _headerRaw = null;
    headers ??= <Header>[];
    headers.add(Header(name, value));
  }

  void addPart(MimePart part) {
    parts ??= <MimePart>[];
    parts.add(part);
  }

  ContentTypeHeader getHeaderContentType() {
    if (_contentTypeHeader != null) {
      return _contentTypeHeader;
    }
    var value = getHeaderValue('content-type');
    if (value == null) {
      return null;
    }
    _contentTypeHeader = ContentTypeHeader.fromValue(value);
    return _contentTypeHeader;
  }

  /// Decodes the value of the first matching header
  String decodeHeaderValue(String name) {
    var value = getHeaderValue(name);
    try {
      return EncodingsHelper.decodeAny(value);
    } catch (e) {
      print('Unable to decode header [$name: $value]: $e');
      return value;
    }
  }

  /// Decodes the a date value of the first matching header
  DateTime decodeHeaderDateValue(String name) {
    return EncodingsHelper.decodeDate(getHeaderValue(name));
  }

  /// Decodes the email address value of first matching header
  List<MailAddress> decodeHeaderMailAddressValue(String name) {
    return MailAddressParser.parseEmailAddreses(getHeaderValue(name));
  }

  String decodeContentText() {
    if (text == null) {
      return null;
    }
    var contentType = getHeaderContentType();
    if (contentType == null || contentType.topLevelType != 'text') {
      return text;
    }
    var characterEncoding = 'utf-8';
    if (contentType.charset != null) {
      characterEncoding = contentType.charset;
    }
    var transferEncoding =
        getHeaderValue('content-transfer-encoding')?.toLowerCase() ?? 'none';
    return EncodingsHelper.decodeText(
        text, transferEncoding, characterEncoding);
  }

  void parse() {
    var body = bodyRaw;
    //print('parse \n[$body]');
    if (headers == null) {
      if (body.startsWith('\r\n')) {
        // this part has no header
        body = body.substring(2);
        text = body;
        headers = <Header>[];
      } else {
        var headerParseResult = ParserHelper.parseHeader(body);
        if (headerParseResult.bodyStartIndex != null) {
          if (headerParseResult.bodyStartIndex >= body.length) {
            body = '';
          } else {
            body = body.substring(headerParseResult.bodyStartIndex);
          }
        }
        headers = headerParseResult.headers
            .map((h) => Header(h.name, h.value))
            .toList();
        text = body;
      }
    }
    var contentType = getHeaderContentType();
    if (contentType?.boundary != null) {
      var splitBoundary = '--' + contentType.boundary + '\r\n';
      var childParts = body.split(splitBoundary);
      if (!body.startsWith(splitBoundary)) {
        // mime-readers can ignore the preamble:
        childParts.removeAt(0);
      }
      var lastPart = childParts.last;
      var closingIndex = lastPart.lastIndexOf('--' + contentType.boundary + '--');
      if (closingIndex != -1) {
        childParts.removeLast();
        lastPart = lastPart.substring(0, closingIndex);
        childParts.add(lastPart);
      }
      for (var childPart in childParts) {
        if (childPart.isNotEmpty) {
          var part = MimePart()..bodyRaw = childPart;
          part.parse();
          addPart(part);
        }
      }
    }
  }

  String _getHeaderRaw() {
    if (_headerRaw != null) {
      return _headerRaw;
    }
    if (headers == null) {
      return null;
    }
    var buffer = StringBuffer();
    for (var header in headers) {
      buffer.write(header.name);
      buffer.write(': ');
      buffer.write(header.value);
      buffer.write('\r\n');
    }
    _headerRaw = buffer.toString();
    return _headerRaw;
  }
}

/// A MIME message
class MimeMessage extends MimePart {
  List<String> rawLines;

  /// The index of the message, if known
  int sequenceId;

  /// Message flags like \Seen, \Recent, etc
  List<String> flags;

  String internalDate;

  int size;

  String subject;
  String date;
  String inReplyTo;
  String messageId;

  String get fromEmail => _getFromEmail();

  /// according to RFC 2822 section 3.6.2. there can be more than one FROM address, in that case the sender MUST be specified
  List<MailAddress> from;
  MailAddress sender;
  List<MailAddress> replyTo;
  List<MailAddress> to;
  List<MailAddress> cc;
  List<MailAddress> bcc;

  Body body;
  List<String> recipients = <String>[];

  void setBodyPart(int partIndex, String content) {
    body ??= Body();
    body.setBodyPart(partIndex, content);
  }

  String getBodyPart(int partIndex) {
    return body?.getBodyPart(partIndex);
  }

  String _getFromEmail() {
    if (from != null && from.isNotEmpty) {
      return from.first.email;
    } else if (headers != null) {
      var fromHeader = getHeader('from')?.first;
      if (fromHeader != null) {
        return ParserHelper.parseEmail(fromHeader.value);
      }
    }
    return null;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    buffer.write('id: [');
    buffer.write(sequenceId);
    buffer.write(']\n');
    if (headers != null) {
      for (var head in headers) {
        head.toStringBuffer(buffer);
        buffer.write('\n');
      }
      buffer.write('\n');
    }
    if (bodyRaw != null) {
      buffer.write(bodyRaw);
    }
    return buffer.toString();
  }
}

class Header {
  String name;
  String value;

  Header(this.name, this.value);

  @override
  String toString() {
    return '$name: $value';
  }

  void toStringBuffer(StringBuffer buffer) {
    buffer.write(name);
    buffer.write(': ');
    buffer.write(value);
  }
}

class BodyAttribute {
  String name;
  String value;

  BodyAttribute(this.name, this.value);
}

class BodyStructure {
  /// A string giving the content media type name as defined in [MIME-IMB].
  /// Examples: text, image
  String type;

  /// A string giving the content subtype name as defined in [MIME-IMB].
  /// Example: plain, html, png
  String subtype;

  /// body parameter parenthesized list as defined in [MIME-IMB].
  List<BodyAttribute> attributes = <BodyAttribute>[];

  /// A string giving the content id as defined in [MIME-IMB].
  String id;

  /// A string giving the content description as defined in [MIME-IMB].
  String description;

  /// A string giving the content transfer encoding as defined in [MIME-IMB].
  /// Examples: 7bit, utf-8, US-ASCII
  String encoding;

  /// A number giving the size of the body in octets.
  /// Note that this size is the size in its transfer encoding and not the
  ///   resulting size after any decoding.
  int size;

  /// Some message types like MESSAGE/RFC822 or TEXT also provide the number of lines
  int numberOfLines;

  BodyStructure(this.type, this.subtype, this.id, this.description,
      this.encoding, this.size);

  void addAttribute(String name, String value) {
    attributes.add(BodyAttribute(name, value));
  }
}

class Body {
  List<BodyStructure> structures = <BodyStructure>[];
  List<String> parts = <String>[];
  String type;

  void addStructure(BodyStructure structure) {
    structures.add(structure);
  }

  void setBodyPart(int partIndex, String content) {
    while (parts.length <= partIndex) {
      parts.add(null);
    }
    parts[partIndex] = content;
  }

  String getBodyPart(int partIndex) {
    if (partIndex >= parts.length) {
      return null;
    }
    return parts[partIndex];
  }
}

/// Eases reading content-type header values
class ContentTypeHeader {
  /// the raw value of the content type header
  String value;

  /// the raw type, e.g. 'text/plain' or 'image/jpeg'
  String mediaType;

  /// the top level [mediaType] like 'text', 'image', 'audio', 'video', 'application', 'multipart' or 'message'
  String topLevelType;

  /// the subtype [mediaType] like 'plain' in 'text/plain' or 'jpeg' in 'image/jpeg'
  String subtype;

  /// the used charset like 'utf-8', this is always converted to lowercase if present
  String charset;

  /// the boundary for content-type headers with a 'multipart' [topLevelType].
  String boundary;

  /// defines wether the 'text/plain' content-header has a 'flowed=true' or semantically equivalent value.
  bool isFlowedFormat;

  /// any additional parameters, for example the 'filename' for an attachment, etc
  Map<String, String> elements = <String, String>{};

  ContentTypeHeader._(this.value);

  static ContentTypeHeader fromValue(String contentTypeValue) {
    var type = ContentTypeHeader._(contentTypeValue);
    var elements = contentTypeValue.split(';');
    var typeText = elements[0].trim().toLowerCase();
    type.mediaType = typeText;
    var splitPos = typeText.indexOf('/');
    if (splitPos != -1) {
      type.topLevelType = typeText.substring(0, splitPos);
      type.subtype = typeText.substring(splitPos + 1);
    }
    for (var i = 1; i < elements.length; i++) {
      var element = elements[i].trim();
      splitPos = element.indexOf('=');
      if (splitPos == -1) {
        type.elements[element] = '';
      } else {
        var name = element.substring(0, splitPos).toLowerCase();
        var value = element.substring(splitPos + 1);
        var valueWithoutQuotes = value;
        if (value.startsWith('"') && value.endsWith('"')) {
          valueWithoutQuotes = value.substring(1, value.length - 1);
        }
        type.elements[name] = value;
        if (name == 'charset') {
          type.charset = valueWithoutQuotes.toLowerCase();
        } else if (name == 'boundary') {
          type.boundary = valueWithoutQuotes;
        } else if (name == 'format') {
          type.isFlowedFormat = valueWithoutQuotes.toLowerCase() == 'flowed';
        }
      }
    }
    return type;
  }
}
