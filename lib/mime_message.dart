import 'package:enough_mail/encodings.dart';
import 'package:enough_mail/date_encoding.dart';
import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/media_type.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/util/mail_address_parser.dart';

/// Common flags for messages
enum MessageFlag { answered, flagged, deleted, seen, draft }

/// A MIME part
/// In a simple case a MIME message only has one MIME part.
class MimePart {
  List<Header> headers;
  String _headerRaw;

  bool _isParsed = false;
  String get headerRaw => _getHeaderRaw();
  set headerRaw(String headerRaw) => _headerRaw = headerRaw;

  String bodyRaw;
  String text;
  List<MimePart> parts;
  ContentTypeHeader _contentTypeHeader;
  MediaType get mediaType => _getMediaType();

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

  Iterable<Header> _getHeaderLowercase(String name) {
    if (!_isParsed) {
      parse();
    }
    return headers?.where((h) => h.name.toLowerCase() == name);
  }

  void addHeader(String name, String value) {
    _headerRaw = null;
    headers ??= <Header>[];
    headers.add(Header(name, value));
  }

  void addPart(MimePart part) {
    parts ??= <MimePart>[];
    parts.add(part);
  }

  /// Retrieves the first 'content-type' header.
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

  /// Retrieves the media type of this part.
  MediaType _getMediaType() {
    var header = getHeaderContentType();
    return header?.mediaType ?? MediaType.textPlain;
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
    return DateEncoding.decodeDate(getHeaderValue(name));
  }

  /// Decodes the email address value of first matching header
  List<MailAddress> decodeHeaderMailAddressValue(String name) {
    return MailAddressParser.parseEmailAddreses(getHeaderValue(name));
  }

  /// Decodes the text of this part.
  String decodeContentText() {
    text ??= bodyRaw;
    if (text == null) {
      return null;
    }
    var contentType = getHeaderContentType();
    if (contentType == null || contentType.mediaType.top != MediaToptype.text) {
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

  /// Checks if this MIME part is textual.
  bool isTextMediaType() {
    return mediaType.isText;
  }

  /// Checks if this MIME part or a child is textual.
  ///
  /// [depth] optional depth, use 1 if only direct children should be checked
  bool hasTextPart({int depth}) {
    if (isTextMediaType()) {
      return true;
    }
    if (parts != null) {
      if (depth != null) {
        if (--depth < 0) {
          return false;
        }
      }
      for (var part in parts) {
        if (part.hasTextPart(depth: depth)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if this MIME part or a child is of the specified media type
  ///
  /// [subtype] the desired media type
  /// [depth] optional depth, use 1 if only direct children should be checked
  bool hasPart(MediaSubtype subtype, {int depth}) {
    if (mediaType.sub == subtype) {
      return true;
    }
    if (parts != null) {
      if (depth != null) {
        if (--depth < 0) {
          return false;
        }
      }
      for (var part in parts) {
        if (part.hasPart(subtype, depth: depth)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Tries to find a 'content-type: text/plain' part and decodes its contents when found.
  String decodePlainTextPart() {
    if (!_isParsed) {
      parse();
    }
    return _decodeTextPart(this, MediaSubtype.textPlain);
  }

  /// Tries to find a 'content-type: text/html' part and decodes its contents when found.
  String decodeHtmlTextPart() {
    if (!_isParsed) {
      parse();
    }
    return _decodeTextPart(this, MediaSubtype.textHtml);
  }

  static String _decodeTextPart(MimePart part, MediaSubtype subtype) {
    var mediaType = part.mediaType;
    if (mediaType.sub == subtype) {
      return part.decodeContentText();
    }
    if (part.parts != null) {
      for (var childPart in part.parts) {
        var decoded = _decodeTextPart(childPart, subtype);
        if (decoded != null) {
          return decoded;
        }
      }
    }
    return null;
  }

  /// Parses this and all children MIME parts.
  void parse() {
    var body = bodyRaw;
    if (body == null) {
      //print('Unable to parse message without body');
      return;
    }
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
    _isParsed = true;
    var contentType = getHeaderContentType();
    if (contentType?.boundary != null) {
      var splitBoundary = '--' + contentType.boundary + '\r\n';
      var childParts = body.split(splitBoundary);
      if (!body.startsWith(splitBoundary)) {
        // mime-readers can ignore the preamble:
        childParts.removeAt(0);
      }
      var lastPart = childParts.last;
      var closingIndex =
          lastPart.lastIndexOf('--' + contentType.boundary + '--');
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

  List<MailAddress> _from;

  /// according to RFC 2822 section 3.6.2. there can be more than one FROM address, in that case the sender MUST be specified
  List<MailAddress> get from => _getFromAddresses();
  set from(List<MailAddress> list) => _from = list;
  MailAddress _sender;
  MailAddress get sender => _getSenderAddress();
  set sender(MailAddress address) => _sender = address;
  List<MailAddress> _replyTo;
  List<MailAddress> get replyTo => _getReplyToAddresses();
  set replyTo(List<MailAddress> list) => _replyTo = list;
  List<MailAddress> _to;
  List<MailAddress> get to => _getToAddresses();
  set to(List<MailAddress> list) => _to = list;
  List<MailAddress> _cc;
  List<MailAddress> get cc => _getCcAddresses();
  set cc(List<MailAddress> list) => _cc = list;
  List<MailAddress> _bcc;
  List<MailAddress> get bcc => _getBccAddresses();
  set bcc(List<MailAddress> list) => _bcc = list;

  Body body;
  List<String> recipients = <String>[];

  /// Decodes the subject of this message
  String decodeSubject() {
    return decodeHeaderValue('subject');
  }

  void setBodyPart(int partIndex, String content) {
    body ??= Body();
    body.setBodyPart(partIndex, content);
  }

  String getBodyPart(int partIndex) {
    return body?.getBodyPart(partIndex);
  }

  /// Checks if this is a typical text message
  /// Compare [decodePlainTextPart()]
  /// Compare [isTextMessage()]
  /// Compare [decodePlainTextPart()]
  /// Compare [decodeHtmlTextPart()]
  bool isTextMessage() {
    return mediaType.isText ||
        mediaType.sub == MediaSubtype.multipartAlternative &&
            hasTextPart(depth: 1);
  }

  /// Checks if this is a typical text message with a plain text part
  /// Compare [decodePlainTextPart()]
  /// Compare [isTextMessage()]
  bool isPlainTextMessage() {
    return mediaType.sub == MediaSubtype.textPlain ||
        mediaType.sub == MediaSubtype.multipartAlternative &&
            hasPart(MediaSubtype.textPlain, depth: 1);
  }

  List<MailAddress> _getFromAddresses() {
    var addresses = _from;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('from');
      _from = addresses;
    }
    return addresses;
  }

  List<MailAddress> _getReplyToAddresses() {
    var addresses = _replyTo;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('reply-to');
      _replyTo = addresses;
    }
    return addresses;
  }

  List<MailAddress> _getToAddresses() {
    var addresses = _to;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('to');
      _to = addresses;
    }
    return addresses;
  }

  List<MailAddress> _getCcAddresses() {
    var addresses = _cc;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('cc');
      _cc = addresses;
    }
    return addresses;
  }

  List<MailAddress> _getBccAddresses() {
    var addresses = _bcc;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('bcc');
      _bcc = addresses;
    }
    return addresses;
  }

  MailAddress _getSenderAddress() {
    var address = _sender;
    if (address == null) {
      var addresses = decodeHeaderMailAddressValue('sender');
      if (addresses?.isNotEmpty ?? false) {
        address = addresses.first;
      }
      _sender = address;
    }
    return address;
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
    var buffer = StringBuffer()
      ..write('id: [')
      ..write(sequenceId)
      ..write(']\n');
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

/// Encapsulates a MIME header
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

  MediaType mediaType;

  /// the used charset like 'utf-8', this is always converted to lowercase if present
  String charset;

  /// the boundary for content-type headers with a 'multipart' [topLevelTypeText].
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
    type.mediaType = MediaType.fromText(typeText);

    for (var i = 1; i < elements.length; i++) {
      var element = elements[i].trim();
      var splitPos = element.indexOf('=');
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
