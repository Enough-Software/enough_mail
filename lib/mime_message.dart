import 'dart:typed_data';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:enough_mail/codecs/date_codec.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/mail_conventions.dart';
import 'package:enough_mail/media_type.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/util/ascii_runes.dart';
import 'package:enough_mail/mime_data.dart';
import 'package:enough_mail/src/util/mail_address_parser.dart';

/// A MIME part
/// In a simple case a MIME message only has one MIME part.
class MimePart {
  /// The `headers` field contains all message(part) headers
  List<Header>? headers;

  /// The raw message data of this part. May or may not include headers, depending on retrieval.
  MimeData? mimeData;

  /// The children of this part, if any.
  ///
  List<MimePart>? parts;

  bool _isParsed = false;
  String? _decodedText;
  DateTime? _decodedDate;
  ContentTypeHeader? _contentTypeHeader;
  ContentDispositionHeader? _contentDispositionHeader;

  /// Simplified way to retrieve the media type
  /// When no `content-type` header is defined, the media type `text/plain` is returned
  MediaType get mediaType {
    final header = getHeaderContentType();
    return header?.mediaType ?? MediaType.textPlain;
  }

  /// Retrieves the raw value of the first matching header.
  ///
  /// Some headers may contain encoded values such as '=?utf-8?B?<data>?='.
  /// Compare [decodeHeaderValue] for retrieving the header value in decoded form.
  /// Compare [getHeader] for retrieving the full header with the given name.
  String? getHeaderValue(String name) {
    return _getLowerCaseHeaderValue(name.toLowerCase());
  }

  /// Retrieves the raw value of the first matching header.
  ///
  /// Some headers may contain encoded values such as '=?utf-8?B?<data>?='.
  /// Compare [decodeHeaderValue] for retrieving the header value in decoded form.
  /// Compare [getHeader] for retrieving the full header with the given name.
  String? _getLowerCaseHeaderValue(String name) {
    final matchingHeaders = _getHeaderLowercase(name);
    if (matchingHeaders?.isNotEmpty ?? false) {
      return matchingHeaders!.first.value;
    }
    return null;
  }

  /// Checks if this MIME part has a header with the specified [name].
  bool hasHeader(String name) => _hasHeaderLowercase(name.toLowerCase());

  bool _hasHeaderLowercase(String name) {
    if (!_isParsed) {
      parse();
    }
    return (headers?.firstWhereOrNull((h) => h.lowerCaseName == name) != null);
  }

  /// Retrieves all matching headers with the specified [name].
  Iterable<Header>? getHeader(String name) =>
      _getHeaderLowercase(name.toLowerCase());

  Iterable<Header>? _getHeaderLowercase(String name) {
    if (!_isParsed) {
      parse();
    }
    return headers?.where((h) => h.lowerCaseName == name);
  }

  /// Adds a header with the specified [name] and [value].
  void addHeader(String name, String? value) {
    headers ??= <Header>[];
    final header = Header(name, value);
    headers!.add(header);
  }

  /// Sets a header with the specified [name] and [value], replacing any existing header with the same [name].
  void setHeader(String name, String? value) {
    headers ??= <Header>[];
    final lowerCaseName = name.toLowerCase();
    headers!.removeWhere((h) => h.lowerCaseName == lowerCaseName);
    headers!.add(Header(name, value));
  }

  void insertPart(MimePart part) {
    parts ??= <MimePart>[];
    parts!.insert(0, part);
  }

  void addPart(MimePart part) {
    parts ??= <MimePart>[];
    parts!.add(part);
  }

  /// Retrieves the first 'content-type' header.
  ContentTypeHeader? getHeaderContentType() {
    if (_contentTypeHeader == null) {
      final value = _getLowerCaseHeaderValue('content-type');
      if (value == null) {
        return null;
      }
      _contentTypeHeader = ContentTypeHeader(value);
    }
    return _contentTypeHeader;
  }

  /// Retrieves the first 'content-disposition' header.
  ContentDispositionHeader? getHeaderContentDisposition() {
    if (_contentDispositionHeader != null) {
      return _contentDispositionHeader;
    }
    final value = _getLowerCaseHeaderValue('content-disposition');
    if (value == null) {
      return null;
    }
    _contentDispositionHeader = ContentDispositionHeader(value);
    return _contentDispositionHeader;
  }

  /// Adds the matching disposition header with the specified [disposition] of this part and this children parts to the [result].
  /// Optionally set [reverse] to `true` to add all parts that do not match the specified `disposition`.
  void collectContentInfo(
      ContentDisposition disposition, List<ContentInfo> result, String? fetchId,
      {bool reverse = false}) {
    var header = getHeaderContentDisposition();
    if ((!reverse && header?.disposition == disposition) ||
        (reverse && header?.disposition != disposition)) {
      var info = ContentInfo()
        ..contentDisposition = header
        ..contentType = getHeaderContentType()
        ..fetchId = fetchId ?? '1'
        ..cid = _getLowerCaseHeaderValue('content-id');
      result.add(info);
    }
    if (parts?.isNotEmpty ?? false) {
      for (var i = 0; i < parts!.length; i++) {
        var part = parts![i];
        part.collectContentInfo(disposition, result,
            fetchId != null ? '$fetchId.${i + 1}' : '${i + 1}',
            reverse: reverse);
      }
    }
  }

  /// Decodes the value of the first matching header
  String? decodeHeaderValue(String name) {
    final value = getHeaderValue(name);
    try {
      return MailCodec.decodeHeader(value);
    } catch (e) {
      print('Unable to decode header [$name: $value]: $e');
      return value;
    }
  }

  /// Decodes the message 'date' header to UTC time.
  /// Call `decodeDate()?.toLocal()` to receive the local date time.
  DateTime? decodeDate() {
    _decodedDate ??= decodeHeaderDateValue('date');
    return _decodedDate;
  }

  /// Tries to find and decode the associated file name
  String? decodeFileName() {
    return MailCodec.decodeHeader((getHeaderContentDisposition()?.filename ??
        getHeaderContentType()?.parameters['name']));
  }

  /// Decodes the a date value of the first matching header
  /// Retrieves the UTC DateTime of the specified header
  DateTime? decodeHeaderDateValue(String name) {
    return DateCodec.decodeDate(getHeaderValue(name));
  }

  /// Decodes the email address value of first matching header
  List<MailAddress>? decodeHeaderMailAddressValue(String name) {
    return MailAddressParser.parseEmailAddreses(getHeaderValue(name));
  }

  /// Decodes the text of this part.
  String? decodeContentText() {
    _decodedText ??= mimeData?.decodeText(
      getHeaderContentType(),
      _getLowerCaseHeaderValue('content-transfer-encoding'),
    );
    return _decodedText;
  }

  /// Decodes the binary data of this part.
  Uint8List? decodeContentBinary() {
    if (mimeData != null) {
      return mimeData!.decodeBinary(
        _getLowerCaseHeaderValue('content-transfer-encoding'),
      );
    }
    return null;
  }

  /// Checks if this MIME part is textual.
  bool isTextMediaType() {
    return mediaType.isText;
  }

  /// Checks if this MIME part or a child is textual.
  ///
  /// [depth] optional depth, use 1 if only direct children should be checked
  bool hasTextPart({int? depth}) {
    if (isTextMediaType()) {
      return true;
    }
    if (parts != null) {
      if (depth != null) {
        if (--depth < 0) {
          return false;
        }
      }
      for (var part in parts!) {
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
  bool hasPart(MediaSubtype subtype, {int? depth}) {
    if (mediaType.sub == subtype) {
      return true;
    }
    if (parts != null) {
      if (depth != null) {
        if (--depth < 0) {
          return false;
        }
      }
      for (var part in parts!) {
        if (part.hasPart(subtype, depth: depth)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Tries to find a 'content-type: text/plain' part and decodes its contents when found.
  String? decodeTextPlainPart() {
    return _decodeTextPart(this, MediaSubtype.textPlain);
  }

  /// Tries to find a 'content-type: text/html' part and decodes its contents when found.
  String? decodeTextHtmlPart() {
    return _decodeTextPart(this, MediaSubtype.textHtml);
  }

  static String? _decodeTextPart(MimePart part, MediaSubtype subtype) {
    if (!part._isParsed) {
      part.parse();
    }
    var mediaType = part.mediaType;
    if (mediaType.sub == subtype) {
      return part.decodeContentText();
    }
    if (part.parts != null) {
      for (var childPart in part.parts!) {
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
    _isParsed = true;
    if (mimeData != null) {
      mimeData!.parse(null);
      if (mimeData!.containsHeader) {
        headers = mimeData!.headersList;
      }
      if (mimeData!.hasParts) {
        parts = [];
        for (final dataPart in mimeData!.parts!) {
          final part = MimePart()
            ..mimeData = dataPart
            ..headers = dataPart.headersList;
          parts!.add(part);
          part.parse();
        }
      }
    } else if (parts != null) {
      for (final part in parts!) {
        part.parse();
      }
    }
  }

  /// Renders this mime part with all children parts into the specified [buffer].
  ///
  /// You can set [renderHeader] to `false` when the message headers should not be rendered.
  void render(StringBuffer buffer, {bool renderHeader = true}) {
    if (mimeData != null) {
      if (!mimeData!.containsHeader && renderHeader) {
        _renderHeaders(buffer);
        buffer.write('\r\n');
      }
      mimeData!.render(buffer);
    } else {
      if (renderHeader) {
        _renderHeaders(buffer);
        buffer.write('\r\n');
      }
      if (parts?.isNotEmpty ?? false) {
        final multiPartBoundary = getHeaderContentType()?.boundary;
        if (multiPartBoundary == null) {
          throw StateError(
              'mime message rendering error: parts present but no multiPartBoundary defined.');
        }
        for (final part in parts!) {
          buffer.write('--');
          buffer.write(multiPartBoundary);
          buffer.write('\r\n');
          part.render(buffer);
          buffer.write('\r\n');
        }
        buffer.write('--');
        buffer.write(multiPartBoundary);
        buffer.write('--');
        buffer.write('\r\n');
      }
    }
  }

  void _renderHeaders(StringBuffer buffer) {
    if (headers != null) {
      for (final header in headers!) {
        header.render(buffer);
      }
    }
  }
}

/// A MIME message
class MimeMessage extends MimePart {
  /// The index of the message, if known
  int? sequenceId;

  /// The uid of the message, if known
  int? uid;

  /// The modifications sequence of this message.
  /// This is only returned by servers that support the CONDSTORE capability and can be fetch explicitely with 'MODSEQ'.
  int? modSequence;

  /// Message flags like \Seen, \Recent, etc
  List<String>? flags;

  /// The internal date of the message on the recipient's provider server
  String? internalDate;

  /// The size of the message in bytes
  int? size;

  /// Checks if this message has been read
  bool get isSeen => hasFlag(MessageFlags.seen);

  /// Sets the `\Seen` flag for this message
  set isSeen(bool value) => setFlag(MessageFlags.seen, value);

  /// Checks if this message has been replied
  bool get isAnswered => hasFlag(MessageFlags.answered);

  /// Sets the `\Answered` flag for this message
  set isAnswered(bool value) => setFlag(MessageFlags.answered, value);

  /// Checks if this message has been forwarded
  bool get isForwarded => hasFlag(MessageFlags.keywordForwarded);

  /// Sets the `$Forwarded` keyword flag for this message
  set isForwarded(bool value) => setFlag(MessageFlags.keywordForwarded, value);

  /// Checks if this message has been marked as important / flagged
  bool get isFlagged => hasFlag(MessageFlags.flagged);

  /// Sets the `\Flagged` flag for this message
  set isFlagged(bool value) => setFlag(MessageFlags.flagged, value);

  /// Checks if this message has been marked as deleted
  bool get isDeleted => hasFlag(MessageFlags.deleted);

  /// Sets the `\Deleted` flag for this message
  set isDeleted(bool value) => setFlag(MessageFlags.deleted, value);

  /// Checks if a read receipt has been sent for this message
  bool get isMdnSent => hasFlag(MessageFlags.keywordMdnSent);

  /// Sets the `$MDNSent` keyword flag for this message
  set isMdnSent(bool value) => setFlag(MessageFlags.keywordMdnSent, value);

  /// Checks if this message contents has been downloaded
  bool get isDownloaded =>
      ((mimeData != null) || (_individualParts?.isNotEmpty ?? false));

  String? get fromEmail => _getFromEmail();

  List<MailAddress>? _from;

  /// according to RFC 2822 section 3.6.2. there can be more than one FROM address, in that case the sender MUST be specified
  List<MailAddress>? get from => _getFromAddresses();
  set from(List<MailAddress>? list) => _from = list;
  MailAddress? _sender;
  MailAddress? get sender => _getSenderAddress();
  set sender(MailAddress? address) => _sender = address;
  List<MailAddress>? _replyTo;
  List<MailAddress>? get replyTo => _getReplyToAddresses();
  set replyTo(List<MailAddress>? list) => _replyTo = list;
  List<MailAddress>? _to;
  List<MailAddress>? get to => _getToAddresses();
  set to(List<MailAddress>? list) => _to = list;
  List<MailAddress>? _cc;
  List<MailAddress>? get cc => _getCcAddresses();
  set cc(List<MailAddress>? list) => _cc = list;
  List<MailAddress>? _bcc;
  List<MailAddress>? get bcc => _getBccAddresses();
  set bcc(List<MailAddress>? list) => _bcc = list;
  Map<String, MimePart>? _individualParts;

  /// The body structure of the message.
  /// This field is only populated when fetching either `BODY`, `BODYSTRUCTURE` elements.
  BodyPart? body;

  Envelope? _envelope;

  /// The envelope of the message.
  /// This field is only populated when fetching `ENVELOPE`.
  Envelope? get envelope => _envelope;
  set envelope(Envelope? value) {
    _envelope = value;
    if (value != null) {
      from = value.from;
      to = value.to;
      cc = value.cc;
      bcc = value.bcc;
      replyTo = value.replyTo;
      sender = value.sender;
    }
  }

  /// Retrieves the mail addresses of all message recipients
  List<String> get recipientAddresses => _collectRecipientsAddresses();

  String? _decodedSubject;

  /// Decodes the subject of this message
  String? decodeSubject() {
    _decodedSubject ??= decodeHeaderValue('subject');
    return _decodedSubject;
  }

  /// Renders the complete message into a String.
  ///
  /// Optionally exclude the rendering of the headers by setting [renderHeader] to `false`
  /// Internally calls [render(StringBuffer)] to render all mime parts.
  String renderMessage({bool renderHeader = true}) {
    var buffer = StringBuffer();
    render(buffer, renderHeader: renderHeader);
    return buffer.toString();
  }

  /// Creates a new message based on the specified rendered text form.
  ///
  /// Compare [renderMessage()] method for converting a message to text.
  static MimeMessage parseFromText(String text) {
    final message = MimeMessage()..mimeData = TextMimeData(text, true);
    message.parse();
    return message;
  }

  /// Creates a new message based on the specified binary data.
  /// Compare [renderMessage()] method for converting a message to text.
  static MimeMessage parseFromData(Uint8List data) {
    final message = MimeMessage()..mimeData = BinaryMimeData(data, true);
    message.parse();
    return message;
  }

  /// Checks if this is a typical text message
  /// Compare [isTextPlainMessage()]
  /// Compare [decodeTextPlainPart()]
  /// Compare [decodeHtmlTextPart()]
  bool isTextMessage() {
    return mediaType.isText ||
        mediaType.sub == MediaSubtype.multipartAlternative &&
            hasTextPart(depth: 1);
  }

  /// Checks if this is a typical text message with a plain text part
  /// Compare [decodeTextPlainPart()]
  /// Compare [isTextMessage()]
  bool isTextPlainMessage() {
    return mediaType.sub == MediaSubtype.textPlain ||
        mediaType.sub == MediaSubtype.multipartAlternative &&
            hasPart(MediaSubtype.textPlain, depth: 1);
  }

  /// Retrieves the sender of the this message by checking the `reply-to`, `sender` and `from` header values in this order.
  /// Set [combine] to `true` in case you want to combine the addresses from these headers, by default the first non-emptry entry is returned.
  List<MailAddress> decodeSender({bool combine = false}) {
    var replyTo = decodeHeaderMailAddressValue('reply-to') ?? <MailAddress>[];
    if (combine || (replyTo.isEmpty)) {
      var senderValue =
          decodeHeaderMailAddressValue('sender') ?? <MailAddress>[];
      if (combine) {
        replyTo.addAll(senderValue);
      } else {
        replyTo = senderValue;
      }
    }
    if (combine || replyTo.isEmpty) {
      var fromValue = decodeHeaderMailAddressValue('from') ?? <MailAddress>[];
      if (combine) {
        replyTo.addAll(fromValue);
      } else {
        replyTo = fromValue;
      }
    }
    return replyTo;
  }

  /// Checks of this messagin is from the specified [sender] address.
  /// Optionally specify known [aliases] and set [allowPlusAliases] to `true` to allow aliass such as `me+alias@domain.com`.
  /// Set [allowPlusAliases] to `true` in case + aliases like `me+alias@domain.com` are valid.
  bool isFrom(MailAddress sender,
      {List<MailAddress>? aliases, bool allowPlusAliases = false}) {
    return (findSender(sender,
            aliases: aliases, allowPlusAliases: allowPlusAliases) !=
        null);
  }

  /// Finds the matching [sender] address.
  /// Optionally specify known [aliases] and set [allowPlusAliases] to `true` to allow aliass such as `me+alias@domain.com`.
  MailAddress? findSender(MailAddress sender,
      {List<MailAddress>? aliases, bool allowPlusAliases = false}) {
    final searchFor = [sender];
    if (aliases != null) {
      searchFor.addAll(aliases);
    }
    final searchIn = decodeSender(combine: true);
    return MailAddress.getMatch(searchFor, searchIn,
        handlePlusAliases: allowPlusAliases);
  }

  /// Finds the matching [recipient] address.
  /// Optionally specify known [aliases] and set [allowPlusAliases] to `true` to allow aliass such as `me+alias@domain.com`.
  MailAddress? findRecipient(MailAddress recipient,
      {List<MailAddress>? aliases, bool allowPlusAliases = false}) {
    final searchFor = [recipient];
    if (aliases != null) {
      searchFor.addAll(aliases);
    }
    final searchIn = <MailAddress>[];
    if (to != null) {
      searchIn.addAll(to!);
    }
    if (cc != null) {
      searchIn.addAll(cc!);
    }
    return MailAddress.getMatch(searchFor, searchIn,
        handlePlusAliases: allowPlusAliases);
  }

  /// Retrieves all content info of parts with the specified [disposition] `Content-Type`.
  /// By default the content info with `ContentDisposition.attachment` are retrieved.
  /// Typically this used to list all attachments of a message.
  /// Note that either the message contents (`BODY[]`) or the `BODYSTRUCTURE` is required to reliably list all matching content elements.
  List<ContentInfo> findContentInfo(
      {ContentDisposition disposition = ContentDisposition.attachment}) {
    var result = <ContentInfo>[];
    if (parts?.isNotEmpty ?? false || body == null) {
      collectContentInfo(disposition, result, null);
    } else if (body != null) {
      body!.collectContentInfo(disposition, result);
    }
    return result;
  }

  /// Checks if this message has parts with the specified [disposition].
  /// Note that either the full message or the body structure must have been downloaded before.
  bool hasContent(ContentDisposition disposition) {
    return findContentInfo(disposition: disposition).isNotEmpty;
  }

  /// Checks if this message has parts with a `Content-Disposition: attachment` header.
  bool hasAttachments() {
    return hasContent(ContentDisposition.attachment);
  }

  /// Checks if this message contains either explicit attachments or non-textual inline parts.
  bool hasAttachmentsOrInlineNonTextualParts() {
    if (hasAttachments()) {
      return true;
    } else {
      final inlineParts =
          findContentInfo(disposition: ContentDisposition.inline);
      for (final info in inlineParts) {
        if (!info.isText) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks if this message any inline parts.
  bool hasInlineParts() {
    final inlineParts = findContentInfo(disposition: ContentDisposition.inline);
    return inlineParts.isNotEmpty;
  }

  /// Retrieves the part with the specified [fetchId].
  /// Returns null if the part has not been loaded (yet).
  MimePart? getPart(String? fetchId) {
    if (_individualParts != null) {
      var part = _individualParts![fetchId!];
      if (part != null) {
        return part;
      }
    }
    if (fetchId == '1') {
      return this;
    }
    final idParts = fetchId!.split('.').map<int>((part) => int.parse(part));
    MimePart parent = this;
    for (var id in idParts) {
      if (parent.parts == null || parent.parts!.length < id) {
        // this mime message is not fully loaded
        return null;
      }
      parent = parent.parts![id - 1];
    }
    return parent;
  }

  /// Sets the individually loaded [part] with the given [fetchId].
  /// call [getPart(fetchId)] to retrieve a part.
  void setPart(String fetchId, MimePart part) {
    _individualParts ??= <String, MimePart>{};
    final existing = body?.getChildPart(fetchId);
    if (existing != null) {
      part._contentTypeHeader = existing.contentType;
      part._contentDispositionHeader = existing.contentDisposition;
      part.addHeader(
          MailConventions.headerContentTransferEncoding, existing.encoding);
    }
    _individualParts![fetchId] = part;
  }

  /// Puts all parts of this message into a flat sequential list.
  List<MimePart> get allPartsFlat {
    final allParts = <MimePart>[];
    if (_individualParts != null) {
      allParts.addAll(_individualParts!.values);
    }
    _addPartsFlat(this, allParts);
    return allParts;
  }

  void _addPartsFlat(MimePart part, List<MimePart> allParts) {
    allParts.add(part);
    if (part.parts != null) {
      for (final child in part.parts!) {
        _addPartsFlat(child, allParts);
      }
    }
  }

  /// Retrieves the part with the specified Content-ID [cid].
  MimePart? getPartWithContentId(String cid) {
    if (!cid.startsWith('<')) {
      cid = '<$cid>';
    }
    final allParts = allPartsFlat;
    for (final part in allParts) {
      if (part._getLowerCaseHeaderValue('content-id') == cid) {
        return part;
      }
    }
    if (body != null) {
      final bodyPart = body!.findFirstWithContentId(cid);
      if (bodyPart != null) {
        return getPart(bodyPart.fetchId);
      }
    }
    return null;
  }

  void copyIndividualParts(MimeMessage other) {
    if (other._individualParts != null) {
      for (final key in other._individualParts!.keys) {
        setPart(key, other._individualParts![key]!);
      }
    }
  }

  List<MailAddress>? _getFromAddresses() {
    var addresses = _from;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('from');
      _from = addresses;
    }
    return addresses;
  }

  List<MailAddress>? _getReplyToAddresses() {
    var addresses = _replyTo;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('reply-to');
      _replyTo = addresses;
    }
    return addresses;
  }

  List<MailAddress>? _getToAddresses() {
    var addresses = _to;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('to');
      _to = addresses;
    }
    return addresses;
  }

  List<MailAddress>? _getCcAddresses() {
    var addresses = _cc;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('cc');
      _cc = addresses;
    }
    return addresses;
  }

  List<MailAddress>? _getBccAddresses() {
    var addresses = _bcc;
    if (addresses == null) {
      addresses = decodeHeaderMailAddressValue('bcc');
      _bcc = addresses;
    }
    return addresses;
  }

  MailAddress? _getSenderAddress() {
    var address = _sender;
    if (address == null) {
      final addresses = decodeHeaderMailAddressValue('sender');
      if (addresses?.isNotEmpty ?? false) {
        address = addresses!.first;
      }
      _sender = address;
    }
    return address;
  }

  String? _getFromEmail() {
    if (from != null && from!.isNotEmpty) {
      return from!.first.email;
    } else if (headers != null) {
      final fromHeader =
          headers!.firstWhereOrNull((h) => h.lowerCaseName == 'from');
      if (fromHeader != null) {
        return ParserHelper.parseEmail(fromHeader.value!);
      }
    }
    return null;
  }

  @override
  String toString() {
    return renderMessage();
  }

  List<String> _collectRecipientsAddresses() {
    var recipients = <String>[];
    if (to != null) {
      recipients.addAll(to!.map((a) => a.email));
    }
    if (cc != null) {
      recipients.addAll(cc!.map((a) => a.email));
    }
    if (bcc != null) {
      recipients.addAll(bcc!.map((a) => a.email));
    }
    return recipients;
  }

  /// Checks if the messages has the message flag with the specified [name].
  bool hasFlag(String name) {
    return flags != null && flags!.contains(name);
  }

  /// Adds the flag with the specified [name] to this message.
  /// Note that this only affects this message instance and is not persisted or
  /// reported to the mail service automatically.
  void addFlag(String name) {
    if (flags == null) {
      flags = [name];
    } else if (!flags!.contains(name)) {
      flags!.add(name);
    }
  }

  /// Removes the flag with the specified [name] from this message.
  /// Note that this only affects this message instance and is not persisted or
  /// reported to the mail service automatically.
  void removeFlag(String name) {
    if (flags == null) {
      flags = [];
    } else {
      flags!.remove(name);
    }
  }

  /// Adds or removes the flag with the specified [name] to/from this message depending on [value].
  /// Note that this only affects this message instance and is not persisted or
  /// reported to the mail service automatically.
  void setFlag(String name, bool enable) {
    if (enable == true) {
      addFlag(name);
    } else {
      removeFlag(name);
    }
  }

  @override
  String? decodeTextPlainPart() {
    final decoded = super.decodeTextPlainPart();
    if (decoded == null) {
      return _decodeTextPartFromBody(MediaSubtype.textPlain);
    }
    return decoded;
  }

  @override
  String? decodeTextHtmlPart() {
    final decoded = super.decodeTextHtmlPart();
    if (decoded == null) {
      return _decodeTextPartFromBody(MediaSubtype.textHtml);
    }
    return decoded;
  }

  @override
  ContentTypeHeader? getHeaderContentType() {
    var header = super.getHeaderContentType();
    header ??= body?.contentType;
    return header!;
  }

  String? _decodeTextPartFromBody(MediaSubtype subtype) {
    if (body != null) {
      final bodyPart = body!.findFirst(subtype);
      if (bodyPart != null) {
        final part = getPart(bodyPart.fetchId);
        if (part != null) {
          if (!part._isParsed) {
            part.parse();
          }
          if (part.mimeData != null) {
            return part.mimeData!.decodeText(
              bodyPart.contentType,
              bodyPart.encoding,
            );
          }
        }
      }
    }
    return null;
  }
}

/// Encapsulates a MIME header
class Header {
  final String name;
  final String? value;
  String? lowerCaseName;

  Header(this.name, this.value) {
    lowerCaseName = name.toLowerCase();
  }

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
    var length = name.length + ': '.length + value!.length;
    buffer.write(name);
    buffer.write(': ');
    if (length < MailConventions.textLineMaxLength) {
      buffer.write(value);
      buffer.write('\r\n');
    } else {
      var currentLineLength = name.length + ': '.length;
      length -= name.length + ': '.length;
      var runes = value!.runes;
      var startIndex = 0;
      while (length > 0) {
        var chunkLength = MailConventions.textLineMaxLength - currentLineLength;
        if (startIndex + chunkLength >= value!.length) {
          // write reminder:
          buffer.write(value!.substring(startIndex).trim());
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
            value!.substring(startIndex, startIndex + chunkLength).trim());
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

/// A BODY or BODYSTRUCTURE information element
class BodyPart {
  /// Children parts, if present
  List<BodyPart>? parts;

  /// A string giving the content id as defined in [MIME-IMB].
  String? cid;

  /// A string giving the content description as defined in [MIME-IMB].
  String? description;

  /// A string giving the content transfer encoding as defined in [MIME-IMB].
  /// Examples: base64, quoted-printable
  String? encoding;

  /// A number giving the size of the body in octets.
  /// Note that this size is the size in its transfer encoding and not the
  ///   resulting size after any decoding.
  int? size;

  /// Some message types like MESSAGE/RFC822 or TEXT also provide the number of lines
  int? numberOfLines;

  /// The content type infomation.
  ContentTypeHeader? contentType;

  /// The content disposition information. This is constructed when querying BODYSTRUCTURE in a fetch.
  ContentDispositionHeader? contentDisposition;

  /// The raw text of this body part. This is set when fetching the message contents e.g. with `BODY[]`.
  String? bodyRaw;

  /// The envelope, only provided for message/rfc822 structures
  Envelope? envelope;

  /// The ID for fetching this body part, e.g. `1.2` for a part that can then be fetched with the criteria `BODY[1.2]`.
  String? _fetchId;
  String? get fetchId {
    _fetchId ??= _getFetchId();
    return _fetchId;
  }

  BodyPart? _parent;

  BodyPart addPart([BodyPart? childPart]) {
    childPart ??= BodyPart();
    parts ??= <BodyPart>[];
    parts!.add(childPart);
    childPart._parent = this;
    return childPart;
  }

  @override
  String toString() {
    var buffer = StringBuffer();
    write(buffer);
    return buffer.toString();
  }

  void write(StringBuffer buffer, [String padding = '']) {
    buffer..write(padding)..write('[')..write(fetchId)..write(']\n');
    if (contentType != null) {
      buffer.write(padding);
      contentType!.render(buffer);
      buffer.write('\n');
    }
    if (contentDisposition != null) {
      buffer.write(padding);
      contentDisposition!.render(buffer);
      buffer.write('\n');
    }
    if (parts != null && parts!.isNotEmpty) {
      buffer.write(padding);
      buffer.write('[\n');
      var addComma = false;
      for (var part in parts!) {
        if (addComma) {
          buffer.write(padding);
          buffer.write(',\n');
        }
        part.write(buffer, padding + ' ');
        addComma = true;
      }
      buffer.write(padding);
      buffer.write(']\n');
    }
  }

  String? _getFetchId([String? tail]) {
    if (_parent != null) {
      var index = _parent!.parts!.indexOf(this);
      var fetchIdPart = (index + 1).toString();
      if (tail == null) {
        tail = fetchIdPart;
      } else {
        tail = fetchIdPart + '.' + tail;
      }
      return _parent!._getFetchId(tail);
    } else {
      return tail;
    }
  }

  /// Adds the matching disposition header with the specified [disposition] of this part and this children parts to the [result].
  /// Optionally set [reverse] to `true` to add all parts that do not match the specified `disposition`.
  void collectContentInfo(
      ContentDisposition disposition, List<ContentInfo> result,
      {bool? reverse}) {
    reverse ??= false;
    if (fetchId != null) {
      if ((!reverse && contentDisposition?.disposition == disposition) ||
          (reverse &&
              contentDisposition?.disposition != disposition &&
              contentType?.mediaType.top != MediaToptype.multipart)) {
        var info = ContentInfo()
          ..contentDisposition = contentDisposition
          ..contentType = contentType
          ..fetchId = fetchId
          ..cid = cid;
        result.add(info);
      }
    }
    if (parts?.isNotEmpty ?? false) {
      for (var part in parts!) {
        part.collectContentInfo(disposition, result, reverse: reverse);
      }
    }
  }

  BodyPart? findFirst(MediaSubtype subtype) {
    if (contentType?.mediaType.sub == subtype) {
      return this;
    }
    if (parts?.isNotEmpty ?? false) {
      for (var part in parts!) {
        var first = part.findFirst(subtype);
        if (first != null) {
          return first;
        }
      }
    }
    return null;
  }

  BodyPart? getChildPart(String partFetchId) {
    if (fetchId == partFetchId) {
      return this;
    }
    if (parts != null) {
      for (final part in parts!) {
        final match = part.getChildPart(partFetchId);
        if (match != null) {
          return match;
        }
      }
    }
    return null;
  }

  BodyPart? findFirstWithContentId(String partCid) {
    if (cid == partCid) {
      return this;
    }
    if (parts != null) {
      for (final part in parts!) {
        final match = part.findFirstWithContentId(partCid);
        if (match != null) {
          return match;
        }
      }
    }
    return null;
  }
}

class Envelope {
  DateTime? date;
  String? subject;
  List<MailAddress>? from;
  MailAddress? sender;
  List<MailAddress>? replyTo;
  List<MailAddress>? to;
  List<MailAddress>? cc;
  List<MailAddress>? bcc;
  String? inReplyTo;
  String? messageId;
}

class ParameterizedHeader {
  /// The raw value of the header
  String rawValue;

  /// The value without parameters as specified in the header, eg 'text/plain' for a Content-Type header.
  late String value;

  /// Any parameters, for example charset, boundary, filename, etc
  final parameters = <String, String>{};

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
        var valueWithoutQuotes = removeQuotes(value);
        parameters[name] = valueWithoutQuotes;
      }
    }
  }

  String removeQuotes(String value) {
    if (value.startsWith('"') && value.endsWith('"')) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }

  void renderField(
      String name, String? value, bool quote, StringBuffer buffer) {
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

  void renderDateField(String name, DateTime? date, StringBuffer buffer) {
    if (date == null) {
      return;
    }
    renderField(name, DateCodec.encodeDate(date), true, buffer);
  }

  void renderRemainingFields(StringBuffer buffer, {List<String>? exclude}) {
    for (var key in parameters.keys) {
      if (!exclude!.contains(key.toLowerCase())) {
        renderField(key, parameters[key], false, buffer);
      }
    }
  }

  /// Adds a new or replaces and existing parameter [name] with the value [quotedValue].
  void setParameter(String name, String quotedValue) {
    parameters[name] = quotedValue;
  }
}

/// Eases reading content-type header values
class ContentTypeHeader extends ParameterizedHeader {
  late MediaType mediaType;

  /// the used charset like 'utf-8', this is always converted to lowercase if present
  String? charset;

  /// the boundary for content-type headers with a 'multipart' [topLevelTypeText].
  String? boundary;

  /// defines wether the 'text/plain' content-header has a 'flowed=true' or semantically equivalent value.
  bool? isFlowedFormat;

  ContentTypeHeader(String rawValue) : super(rawValue) {
    mediaType = MediaType.fromText(value);
    charset = parameters['charset']?.toLowerCase();
    boundary = parameters['boundary'];
    if (parameters.containsKey('format')) {
      isFlowedFormat = parameters['format']!.toLowerCase() == 'flowed';
    }
  }

  String render([StringBuffer? buffer]) {
    buffer ??= StringBuffer();
    buffer.write(value);
    renderField('charset', charset, true, buffer);
    renderField('boundary', boundary, true, buffer);
    if (isFlowedFormat == true) {
      renderField('format', 'flowed', false, buffer);
    }
    renderRemainingFields(buffer, exclude: ['charset', 'boundary', 'format']);
    return buffer.toString();
  }

  @override
  void setParameter(String name, String? quotedValue) {
    name = name.toLowerCase();
    if (name == 'charset') {
      quotedValue = removeQuotes(quotedValue!).toLowerCase();
      charset = quotedValue;
    } else if (name == 'boundary') {
      quotedValue = removeQuotes(quotedValue!);
      boundary = quotedValue;
    } else if (name == 'format') {
      quotedValue = removeQuotes(quotedValue!).toLowerCase();
      isFlowedFormat = (quotedValue == 'flowed');
    }
    super.setParameter(name, quotedValue!);
  }

  static ContentTypeHeader from(MediaType mediaType,
      {String? charset, String? boundary, bool? isFlowedFormat}) {
    var type = ContentTypeHeader(mediaType.text);
    type.charset = charset;
    type.boundary = boundary;
    type.isFlowedFormat = isFlowedFormat;
    return type;
  }
}

/// Specifies the content disposition of a mime part.
/// Compare https://tools.ietf.org/html/rfc2183 for details.
enum ContentDisposition { inline, attachment, other }

/// Specifies the content disposition header of a mime part.
/// Compare https://tools.ietf.org/html/rfc2183 for details.
class ContentDispositionHeader extends ParameterizedHeader {
  late String dispositionText;
  late ContentDisposition disposition;
  String? filename;
  DateTime? creationDate;
  DateTime? modificationDate;
  DateTime? readDate;
  int? size;

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

    filename = MailCodec.decodeHeader(parameters['filename']);
    creationDate = DateCodec.decodeDate(parameters['creation-date']);
    modificationDate = DateCodec.decodeDate(parameters['modification-date']);
    readDate = DateCodec.decodeDate(parameters['read-date']);
    var sizeText = parameters['size'];
    if (sizeText != null) {
      size = int.tryParse(sizeText);
    }
  }

  static ContentDispositionHeader from(ContentDisposition disposition,
      {String? filename,
      DateTime? creationDate,
      DateTime? modificationDate,
      DateTime? readDate,
      int? size}) {
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

  String render([StringBuffer? buffer]) {
    buffer ??= StringBuffer();
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

  @override
  void setParameter(String name, String? quotedValue) {
    name = name.toLowerCase();
    if (name == 'filename') {
      quotedValue = removeQuotes(quotedValue!).toLowerCase();
      filename = quotedValue;
    } else if (name == 'creation-date') {
      quotedValue = removeQuotes(quotedValue!);
      creationDate = DateCodec.decodeDate(quotedValue);
    } else if (name == 'modification-date') {
      quotedValue = removeQuotes(quotedValue!);
      modificationDate = DateCodec.decodeDate(quotedValue);
    } else if (name == 'read-date') {
      quotedValue = removeQuotes(quotedValue!);
      readDate = DateCodec.decodeDate(quotedValue);
    } else if (name == 'size') {
      size = int.tryParse(quotedValue!);
    }
    super.setParameter(name, quotedValue!);
  }
}

/// Provides high level information about content parts.
/// Compare MimeMessage.listContentInfo().
class ContentInfo {
  ContentDispositionHeader? contentDisposition;
  ContentTypeHeader? contentType;
  String? fetchId;
  String? cid;
  String? _decodedFileName;
  String? get fileName {
    _decodedFileName ??= MailCodec.decodeHeader(
        (contentDisposition?.filename ?? contentType?.parameters['name']));
    return _decodedFileName;
  }

  int? get size => contentDisposition!.size;
  MediaType? get mediaType => contentType?.mediaType;
  bool get isImage => mediaType?.top == MediaToptype.image;
  bool get isText => mediaType?.top == MediaToptype.text;
  bool get isModel => mediaType?.top == MediaToptype.model;
  bool get isAudio => mediaType?.top == MediaToptype.audio;
  bool get isApplication => mediaType?.top == MediaToptype.application;
  bool get isFont => mediaType?.top == MediaToptype.font;
  bool get isMessage => mediaType?.top == MediaToptype.message;
  bool get isVideo => mediaType?.top == MediaToptype.video;
  bool get isMultipart => mediaType?.top == MediaToptype.multipart;
  bool get isOther => mediaType?.top == MediaToptype.other;
}
