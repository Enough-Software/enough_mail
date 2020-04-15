import 'dart:typed_data';

import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:enough_mail/codecs/date_codec.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/mail_conventions.dart';
import 'package:enough_mail/media_type.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/util/ascii_runes.dart';
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
  ContentDispositionHeader _contentDispositionHeader;
  MediaType get mediaType => _getMediaType();

  /// Used during message construction / rendering: boundary for multipart messages
  String multiPartBoundary;

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

  /// Retrieves all matching headers with the specified [name].
  Iterable<Header> getHeader(String name) =>
      _getHeaderLowercase(name.toLowerCase());

  Iterable<Header> _getHeaderLowercase(String name) {
    if (!_isParsed) {
      parse();
    }
    return headers?.where((h) => h.name.toLowerCase() == name);
  }

  /// Adds a header with the specified [name] and [value].
  void addHeader(String name, String value) {
    _headerRaw = null;
    headers ??= <Header>[];
    headers.add(Header(name, value));
  }

  /// Sets a header with the specified [name] and [value], replacing any existing header with the same [name].
  void setHeader(String name, String value) {
    _headerRaw = null;
    if (headers != null) {
      var lowercaseName = name.toLowerCase();
      headers.removeWhere((h) => h.name.toLowerCase() == lowercaseName);
    } else {
      headers = <Header>[];
    }
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
    _contentTypeHeader = ContentTypeHeader(value);
    return _contentTypeHeader;
  }

  /// Retrieves the first 'content-disposition' header.
  ContentDispositionHeader getHeaderContentDisposition() {
    if (_contentDispositionHeader != null) {
      return _contentDispositionHeader;
    }
    var value = getHeaderValue('content-disposition');
    if (value == null) {
      return null;
    }
    _contentDispositionHeader = ContentDispositionHeader(value);
    return _contentDispositionHeader;
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
      return MailCodec.decodeAny(value);
    } catch (e) {
      print('Unable to decode header [$name: $value]: $e');
      return value;
    }
  }

  /// Decodes the a date value of the first matching header
  DateTime decodeHeaderDateValue(String name) {
    return DateCodec.decodeDate(getHeaderValue(name));
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
    return MailCodec.decodeAnyText(text, transferEncoding, characterEncoding);
  }

  /// Decodes the binary data of this part.
  Uint8List decodeContentBinary() {
    text ??= bodyRaw;
    if (text == null) {
      return null;
    }
    var transferEncoding =
        getHeaderValue('content-transfer-encoding')?.toLowerCase() ?? 'none';
    return MailCodec.decodeBinary(text, transferEncoding);
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
    return _decodeTextPart(this, MediaSubtype.textPlain);
  }

  /// Tries to find a 'content-type: text/html' part and decodes its contents when found.
  String decodeHtmlTextPart() {
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

  /// Renders this mime part with all children parts into the specified [buffer].
  void render(StringBuffer buffer) {
    if (headers != null) {
      for (var header in headers) {
        header.render(buffer);
      }
    } else if (headerRaw != null) {
      buffer.write(headerRaw);
    }
    buffer.write('\r\n');
    if (parts?.isNotEmpty ?? false) {
      if (multiPartBoundary == null) {
        throw StateError(
            'mime message rendering error: parts present but no multiPartBoundary defined.');
      }
      for (var part in parts) {
        buffer.write('--');
        buffer.write(multiPartBoundary);
        buffer.write('\r\n');
        part.render(buffer);
      }
      buffer.write('--');
      buffer.write(multiPartBoundary);
      buffer.write('--');
      buffer.write('\r\n');
    } else if (bodyRaw != null) {
      buffer.write(bodyRaw);
      buffer.write('\r\n');
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

  // Retrieves the mail addresses of all message recipients
  List<String> get recipientAddresses => _collectRecipientsAddresses();

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

  /// Renders the complete message into a String.
  /// Internally calls [render(StringBuffer)] to render all mime parts.
  String renderMessage() {
    var buffer = StringBuffer();
    render(buffer);
    return buffer.toString();
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

  List<String> _collectRecipientsAddresses() {
    var recipients = <String>[];
    if (to != null) {
      recipients.addAll(to.map((a) => a.email));
    }
    if (cc != null) {
      recipients.addAll(cc.map((a) => a.email));
    }
    if (bcc != null) {
      recipients.addAll(bcc.map((a) => a.email));
    }
    return recipients;
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

  void render(StringBuffer buffer) {
    var length = name.length + ': '.length + value.length;
    buffer.write(name);
    buffer.write(': ');
    if (length < MailConventions.textLineMaxLength) {
      buffer.write(value);
      buffer.write('\r\n');
    } else {
      var currentLineLength = name.length + ': '.length;
      length -= name.length + ': '.length;
      var runes = value.runes;
      var startIndex = 0;
      while (length > 0) {
        var chunkLength = MailConventions.textLineMaxLength - currentLineLength;
        if (startIndex + chunkLength > value.length) {
          // write reminder:
          buffer.write(value.substring(startIndex).trim());
          buffer.write('\r\n');
          break;
        }
        for (var runeIndex = startIndex + chunkLength;
            runeIndex > startIndex;
            runeIndex--) {
          var rune = runes.elementAt(runeIndex);
          if (rune == AsciiRunes.runeSemicolon ||
              rune == AsciiRunes.runeSpace ||
              rune == AsciiRunes.runeClosingParentheses ||
              rune == AsciiRunes.runeClosingBracket ||
              rune == AsciiRunes.runeGreaterThan) {
            chunkLength = runeIndex - startIndex + 1;
            break;
          }
        }
        buffer.write(
            value.substring(startIndex, startIndex + chunkLength).trim());
        buffer.write('\r\n');
        length -= chunkLength;
        startIndex += chunkLength;
        if (length > 0) {
          buffer.writeCharCode(AsciiRunes.runeTab);
          currentLineLength = 1;
        }
      }
    }
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

class ParameterizedHeader {
  /// The raw value of the header
  String rawValue;

  /// The value without parameters as specified in the header, eg 'text/plain' for a Content-Type header.
  String value;

  /// Any parameters, for example charset, boundary, filename, etc
  Map<String, String> parameters = <String, String>{};

  ParameterizedHeader(this.rawValue) {
    var elements = rawValue.split(';');
    value = elements[0];
    for (var i = 1; i < elements.length; i++) {
      var element = elements[i].trim();
      var splitPos = element.indexOf('=');
      if (splitPos == -1) {
        parameters[element.toLowerCase()] = '';
      } else {
        var name = element.substring(0, splitPos).toLowerCase();
        var value = element.substring(splitPos + 1);
        var valueWithoutQuotes = value;
        if (value.startsWith('"') && value.endsWith('"')) {
          valueWithoutQuotes = value.substring(1, value.length - 1);
        }
        parameters[name] = valueWithoutQuotes;
      }
    }
  }

  void renderField(String name, String value, bool quote, StringBuffer buffer) {
    if (value == null) {
      return;
    }
    buffer.write('; ');
    buffer.write(name);
    buffer.write('=');
    if (quote) {
      buffer.write('"');
    }
    buffer.write(value);
    if (quote) {
      buffer.write('"');
    }
  }

  void renderDateField(String name, DateTime date, StringBuffer buffer) {
    if (date == null) {
      return;
    }
    renderField(name, DateCodec.encodeDate(date), true, buffer);
  }

  void renderRemainingFields(StringBuffer buffer, {List<String> exclude}) {
    if (parameters != null) {
      for (var key in parameters.keys) {
        if (!exclude.contains(key.toLowerCase())) {
          renderField(key, parameters[key], false, buffer);
        }
      }
    }
  }

  /// Adds a new or replaces and existing parameter [name] with the value [quotedValue].
  void setParameter(String name, String quotedValue) {
    parameters ??= <String, String>{};
    parameters[name] = quotedValue;
  }
}

/// Eases reading content-type header values
class ContentTypeHeader extends ParameterizedHeader {
  MediaType mediaType;

  /// the used charset like 'utf-8', this is always converted to lowercase if present
  String charset;

  /// the boundary for content-type headers with a 'multipart' [topLevelTypeText].
  String boundary;

  /// defines wether the 'text/plain' content-header has a 'flowed=true' or semantically equivalent value.
  bool isFlowedFormat;

  ContentTypeHeader(String rawValue) : super(rawValue) {
    mediaType = MediaType.fromText(value);
    charset = parameters['charset']?.toLowerCase();
    boundary = parameters['boundary'];
    if (parameters.containsKey('format')) {
      isFlowedFormat = parameters['format'].toLowerCase() == 'flowed';
    }
  }
}

/// Specifies the content disposition of a mime part.
/// Compare https://tools.ietf.org/html/rfc2183 for details.
enum ContentDisposition { inline, attachment, other }

/// Specifies the content disposition header of a mime part.
/// Compare https://tools.ietf.org/html/rfc2183 for details.
class ContentDispositionHeader extends ParameterizedHeader {
  String dispositionText;
  ContentDisposition disposition;
  String filename;
  DateTime creationDate;
  DateTime modificationDate;
  DateTime readDate;
  int size;

  ContentDispositionHeader(String rawValue) : super(rawValue) {
    dispositionText = value;
    switch (dispositionText.toLowerCase()) {
      case 'inline':
        disposition = ContentDisposition.inline;
        break;
      case 'attachment':
        disposition = ContentDisposition.attachment;
        break;
      default:
        disposition = ContentDisposition.other;
        break;
    }
    filename = parameters['filename'];
    var creation = parameters['creation-date'];
    if (creation != null) {
      creationDate = DateCodec.decodeDate(creation);
    }
    var modification = parameters['modification-date'];
    if (modification != null) {
      modificationDate = DateCodec.decodeDate(modification);
    }
    var read = parameters['read-date'];
    if (read != null) {
      readDate = DateCodec.decodeDate(read);
    }
    var sizeText = parameters['size'];
    if (sizeText != null) {
      size = int.tryParse(sizeText);
    }
  }

  static ContentDispositionHeader from(ContentDisposition disposition,
      {String filename,
      DateTime creationDate,
      DateTime modificationDate,
      DateTime readDate,
      int size}) {
    var rawValue;
    switch (disposition) {
      case ContentDisposition.inline:
        rawValue = 'inline';
        break;
      case ContentDisposition.attachment:
        rawValue = 'attachment';
        break;
      default:
        rawValue = 'unsupported';
        break;
    }
    var header = ContentDispositionHeader(rawValue);
    header.filename = filename;
    header.creationDate = creationDate;
    header.modificationDate = modificationDate;
    header.readDate = readDate;
    header.size = size;
    return header;
  }

  String render() {
    var buffer = StringBuffer();
    buffer.write(dispositionText);
    renderField('filename', filename, true, buffer);
    renderDateField('creation-date', creationDate, buffer);
    renderDateField('modification-date', modificationDate, buffer);
    renderDateField('read-date', readDate, buffer);
    if (size != null) {
      renderField('size', size.toString(), false, buffer);
    }
    renderRemainingFields(buffer, exclude: [
      'filename',
      'creation-date',
      'modification-date',
      'read-date',
      'size'
    ]);
    return buffer.toString();
  }
}
