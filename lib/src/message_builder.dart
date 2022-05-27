import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:intl/intl.dart';

import 'codecs/date_codec.dart';
import 'codecs/mail_codec.dart';
import 'exception.dart';
import 'mail_address.dart';
import 'mail_conventions.dart';
import 'media_type.dart';
import 'mime_data.dart';
import 'mime_message.dart';
import 'private/util/ascii_runes.dart';

/// The `transfer-encoding` used for encoding 8bit data if necessary
enum TransferEncoding {
  /// this mime message/part only consists of 7bit data, e.g. ASCII text
  sevenBit,

  /// actually daring to transfer 8bit as it is, e.g. UTF8
  eightBit,

  /// Quoted-printable is somewhat human readable
  quotedPrintable,

  /// base64 encoding is used to transfer binary data
  base64,

  /// the automatic options tries to find the best solution
  ///
  /// ie `7bit` for ASCII texts, `quoted-printable` for 8bit texts
  /// and `base64` for binaries.
  automatic
}

/// The used character set
enum CharacterSet {
  /// 7-bit ASCII text
  ascii,

  /// UTF-8 text
  utf8,

  /// latin-1 text
  latin1
}

/// The recipient
enum RecipientGroup {
  /// direct recipients
  to,

  /// recipients on CC (carbon copy)
  cc,

  /// recipients not visible for other recipients
  bcc
}

/// Information about a file that is attached
class AttachmentInfo {
  /// Creates a new attachment info
  AttachmentInfo(this.file, this.mediaType, this.name, this.size,
      this.contentDisposition, this.data, this.part);

  /// The name of the attachment
  final String? name;

  /// The size of the attachment in bytes
  final int? size;

  /// The media type
  final MediaType mediaType;

  /// The content disposition
  final ContentDisposition? contentDisposition;

  /// The associated file
  final File? file;

  /// The associated data
  final Uint8List? data;

  /// The related builder
  final PartBuilder part;
}

/// Allows to configure a mime part
class PartBuilder {
  /// Creates a new part builder
  PartBuilder(
    MimePart mimePart, {
    String? text,
    this.transferEncoding = TransferEncoding.automatic,
    this.characterSet,
    this.contentType,
  }) : _part = mimePart {
    this.text = text;
  }

  String? _text;

  /// the text in this part builder
  String? get text => _text;
  set text(String? value) {
    if (value == null) {
      _text = value;
    } else {
      // replace single LF characters with CR LF in text: (sigh, SMTP)
      final runes = value.runes.toList(growable: false);
      List<int>? copy;
      var foundBareLineFeeds = 0;
      var lastChar = 0;
      for (var i = 0; i < runes.length; i++) {
        final char = runes[i];
        if (char == AsciiRunes.runeLineFeed &&
            (i == 0 || lastChar != AsciiRunes.runeCarriageReturn)) {
          // this is a single LF character
          copy ??= [...runes];
          copy.insert(i + foundBareLineFeeds, AsciiRunes.runeCarriageReturn);
          foundBareLineFeeds++;
        }
        lastChar = char;
      }
      if (copy == null) {
        _text = value;
      } else {
        _text = String.fromCharCodes(copy);
      }
    }
  }

  /// The scheme used for encoding 8bit characters in the [text]
  TransferEncoding transferEncoding;

  /// The char set like ASCII or UTF-8 used in the [text]
  CharacterSet? characterSet;

  /// The media type represented by this part
  ContentTypeHeader? contentType;

  final _attachments = <AttachmentInfo>[];

  /// The attachments in this builder
  List<AttachmentInfo> get attachments => _attachments;

  /// Checks if there is at least 1 attachment
  bool get hasAttachments => _attachments.isNotEmpty;

  final MimePart _part;
  List<PartBuilder>? _children;

  /// The way that this part should be handled, e.g. inline or as attachment.
  ContentDispositionHeader? contentDisposition;

  void _copy(MimePart originalPart) {
    contentType = originalPart.getHeaderContentType();

    if (originalPart.isTextMediaType()) {
      text = originalPart.decodeContentText();
    } else if (originalPart.parts == null) {
      _part.mimeData = originalPart.mimeData;
    }
    final parts = originalPart.parts;
    if (parts != null) {
      for (final part in parts) {
        final childDisposition = part.getHeaderContentDisposition();
        final childBuilder = addPart(
            disposition: childDisposition, mediaSubtype: part.mediaType.sub);
        if (childDisposition?.disposition == ContentDisposition.attachment) {
          final info = AttachmentInfo(
              null,
              part.mediaType,
              part.decodeFileName(),
              null,
              ContentDisposition.attachment,
              part.decodeContentBinary(),
              this);
          _attachments.add(info);
        }
        childBuilder._copy(part);
      }
    }
  }

  /// Creates the content-type based on the specified [mediaType].
  ///
  /// Optionally you can specify the [characterSet], [multiPartBoundary],
  /// [name] or other [parameters].
  void setContentType(MediaType mediaType,
      {CharacterSet? characterSet,
      String? multiPartBoundary,
      String? name,
      Map<String, String>? parameters}) {
    if (mediaType.isMultipart && multiPartBoundary == null) {
      // multiPartBoundary is null and this is a multipart ->
      // define a default boundary:
      // ignore: parameter_assignments
      multiPartBoundary = MessageBuilder.createRandomId();
    }
    contentType = ContentTypeHeader.from(mediaType,
        charset: mediaType.top == MediaToptype.text
            ? MessageBuilder.getCharacterSetName(characterSet)
            : null,
        boundary: multiPartBoundary);
    if (name != null) {
      contentType!.parameters['name'] = '"$name"';
    }
    if (parameters?.isNotEmpty ?? false) {
      contentType!.parameters.addAll(parameters!);
    }
  }

  /// Adds a text part to this message with the specified [text].
  ///
  /// Specify the optional [mediaType], in case this is not a
  /// `text/plain` message
  /// and the [characterSet] in case it is not ASCII.
  ///
  /// Optionally specify the content disposition with [disposition].
  ///
  /// Optionally set [insert] to true to prepend and not append the part.
  ///
  /// Optionally specify the [transferEncoding] which defaults to
  /// [TransferEncoding.automatic].
  PartBuilder addText(String text,
      {MediaType? mediaType,
      TransferEncoding transferEncoding = TransferEncoding.automatic,
      CharacterSet characterSet = CharacterSet.utf8,
      ContentDispositionHeader? disposition,
      bool insert = false}) {
    mediaType ??= MediaSubtype.textPlain.mediaType;
    final child = addPart(insert: insert)
      ..setContentType(mediaType, characterSet: characterSet)
      ..transferEncoding = transferEncoding
      ..contentDisposition = disposition
      ..text = text;
    if (disposition?.disposition == ContentDisposition.attachment) {
      final info = AttachmentInfo(
          null,
          mediaType,
          disposition!.filename,
          disposition.size,
          disposition.disposition,
          utf8.encode(text) as Uint8List,
          child);
      _attachments.add(info);
    }
    return child;
  }

  /// Adds a plain text part
  ///
  /// Compare `addText()` for details.
  PartBuilder addTextPlain(String text,
          {TransferEncoding transferEncoding = TransferEncoding.automatic,
          CharacterSet characterSet = CharacterSet.utf8,
          ContentDispositionHeader? disposition,
          bool insert = false}) =>
      addText(text,
          transferEncoding: transferEncoding,
          characterSet: characterSet,
          disposition: disposition,
          insert: insert);

  /// Adds a HTML text part
  ///
  /// Compare `addText()` for details.
  PartBuilder addTextHtml(String text,
          {TransferEncoding transferEncoding = TransferEncoding.automatic,
          CharacterSet characterSet = CharacterSet.utf8,
          ContentDispositionHeader? disposition,
          bool insert = false}) =>
      addText(text,
          mediaType: MediaSubtype.textHtml.mediaType,
          transferEncoding: transferEncoding,
          characterSet: characterSet,
          disposition: disposition,
          insert: insert);

  /// Adds a new part
  ///
  /// Specify the optional [disposition] in case you want to specify
  /// the content-disposition.
  ///
  /// Optionally specify the [mimePart], if it is already known.
  ///
  /// Optionally specify the [mediaSubtype], e.g.
  /// `MediaSubtype.multipartAlternative`.
  ///
  /// Optionally set [insert] to `true` to prepend and not append the part.
  PartBuilder addPart({
    ContentDispositionHeader? disposition,
    MimePart? mimePart,
    MediaSubtype? mediaSubtype,
    bool insert = false,
  }) {
    final addAttachmentInfo = mimePart != null &&
        mimePart.getHeaderContentDisposition()?.disposition ==
            ContentDisposition.attachment;
    mimePart ??= MimePart();
    final childBuilder = PartBuilder(mimePart);
    if (mediaSubtype != null) {
      childBuilder.setContentType(mediaSubtype.mediaType);
    } else if (mimePart.getHeaderContentType() != null) {
      childBuilder.contentType = mimePart.getHeaderContentType();
    }
    _children ??= <PartBuilder>[];
    if (insert) {
      _part.insertPart(mimePart);
      _children!.insert(0, childBuilder);
    } else {
      _part.addPart(mimePart);
      _children!.add(childBuilder);
    }
    disposition ??= mimePart.getHeaderContentDisposition();
    childBuilder.contentDisposition = disposition;
    if (mimePart.isTextMediaType()) {
      childBuilder.text = mimePart.decodeContentText();
    }
    if (addAttachmentInfo) {
      final info = AttachmentInfo(
          null,
          mimePart.mediaType,
          mimePart.decodeFileName(),
          disposition!.size,
          disposition.disposition,
          mimePart.decodeContentBinary(),
          childBuilder);
      _attachments.add(info);
    }

    return childBuilder;
  }

  /// Retrieves the first builder with a text/plain part.
  ///
  /// Note that only this builder and direct children are queried.
  PartBuilder? getTextPlainPart() => getPart(MediaSubtype.textPlain);

  /// Retrieves the first builder with a text/plain part.
  ///
  /// Note that only this builder and direct children are queried.
  PartBuilder? getTextHtmlPart() => getPart(MediaSubtype.textHtml);

  /// Retrieves the first builder with the specified [mediaSubtype].
  ///
  /// Unless [recursive] is set to `false`, the whole tree is searched
  /// for the given [mediaSubtype].
  PartBuilder? getPart(MediaSubtype mediaSubtype, {bool recursive = true}) {
    final isPlainText = mediaSubtype == MediaSubtype.textPlain;
    if (_children?.isEmpty ?? true) {
      if (contentType?.mediaType.sub == mediaSubtype ||
          (isPlainText && contentType == null)) {
        return this;
      }
      return null;
    }
    for (final child in _children!) {
      if (recursive) {
        final matchingPart = child.getPart(mediaSubtype);
        if (matchingPart != null) {
          return matchingPart;
        }
      } else if ((child.contentType?.mediaType.sub == mediaSubtype) ||
          (isPlainText && child.contentType == null)) {
        return child;
      }
    }
    return null;
  }

  /// Removes the specified attachment [info]
  void removeAttachment(AttachmentInfo info) {
    _attachments.remove(info);
    removePart(info.part);
  }

  /// Removes the specified part [childBuilder]
  void removePart(PartBuilder childBuilder) {
    _part.parts!.remove(childBuilder._part);
    _children!.remove(childBuilder);
  }

  /// Adds the [file] part asynchronously.
  ///
  /// [file] The file that should be added.
  ///
  /// [mediaType] The media type of the file.
  ///
  /// Specify the optional content [disposition] element,
  /// if it should not be populated automatically.
  ///
  /// This will add an `AttachmentInfo` element to the `attachments`
  /// list of this builder.
  Future<PartBuilder> addFile(File file, MediaType mediaType,
      {ContentDispositionHeader? disposition}) async {
    disposition ??=
        ContentDispositionHeader.from(ContentDisposition.attachment);
    disposition.filename ??= _getFileName(file);
    disposition.size ??= await file.length();
    disposition.modificationDate ??= file.lastModifiedSync();
    final child = addPart(disposition: disposition);
    final data = await file.readAsBytes();
    child.transferEncoding = TransferEncoding.base64;
    final info = AttachmentInfo(file, mediaType, disposition.filename,
        disposition.size, disposition.disposition, data, child);
    _attachments.add(info);
    child.setContentType(mediaType, name: disposition.filename);
    child._part.mimeData =
        TextMimeData(MailCodec.base64.encodeData(data), containsHeader: false);
    return child;
  }

  String _getFileName(File file) {
    var name = file.path;
    final lastPathSeparator =
        math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
    if (lastPathSeparator != -1 && lastPathSeparator != name.length - 1) {
      name = name.substring(lastPathSeparator + 1);
    }
    return name;
  }

  /// Adds a binary data part with the given [data] and optional [filename].
  ///
  /// [mediaType] The media type of the file.
  ///
  /// Specify the optional content [disposition] element,
  /// if it should not be populated automatically.
  PartBuilder addBinary(Uint8List data, MediaType mediaType,
      {TransferEncoding transferEncoding = TransferEncoding.base64,
      ContentDispositionHeader? disposition,
      String? filename}) {
    disposition ??= ContentDispositionHeader.from(ContentDisposition.attachment,
        filename: filename, size: data.length);
    final child = addPart(disposition: disposition)
      ..transferEncoding = TransferEncoding.base64
      ..setContentType(mediaType, name: filename);
    final info = AttachmentInfo(null, mediaType, filename, data.length,
        disposition.disposition, data, child);
    _attachments.add(info);
    child._part.mimeData =
        TextMimeData(MailCodec.base64.encodeData(data), containsHeader: false);
    return child;
  }

  /// Adds the message [mimeMessage] as a `message/rfc822` content.
  ///
  /// Optionally  specify the [disposition] which defaults to
  /// [ContentDisposition.attachment].
  PartBuilder addMessagePart(MimeMessage mimeMessage,
      {ContentDisposition disposition = ContentDisposition.attachment}) {
    // message data can be binary or textual
    // even binary message data should not be base64 encoded,
    // since it has itself encodings etc
    final mediaType = MediaSubtype.messageRfc822.mediaType;
    final subject = mimeMessage.decodeSubject()?.replaceAll('"', r'\"');
    final filename = '${subject ?? ''}.eml';
    final messageText = mimeMessage.renderMessage();
    final partBuilder = addPart(
      mimePart: MimePart()
        ..mimeData = TextMimeData(messageText, containsHeader: false),
      mediaSubtype: MediaSubtype.messageRfc822,
      disposition:
          ContentDispositionHeader.from(disposition, filename: filename),
    );
    if (disposition == ContentDisposition.attachment) {
      _attachments.add(
        AttachmentInfo(null, mediaType, filename, null, disposition,
            utf8.encode(messageText) as Uint8List, partBuilder),
      );
    }
    return partBuilder;
  }

  /// Adds a part with the `multipart/alternative` subtype.
  ///
  /// Optionally specify the [plainText] and the [htmlText]. Note that
  /// you need to specify either neither or both.
  ///
  /// Same as `addPart(mediaSubtype: MediaSubtype.multipartAlternative)` when
  /// no texts are given.
  PartBuilder addMultipartAlternative({String? plainText, String? htmlText}) {
    final partBuilder =
        addPart(mediaSubtype: MediaSubtype.multipartAlternative);
    if (plainText != null && htmlText != null) {
      partBuilder
        ..addTextPlain(plainText)
        ..addTextHtml(htmlText);
    }
    return partBuilder;
  }

  /// Adds a header with the specified [name] and [value].
  ///
  /// Compare [MailConventions] for common header names.
  ///
  /// Set [encoding] to any of the [HeaderEncoding] formats
  /// to encode the header.
  void addHeader(String name, String value,
      {HeaderEncoding encoding = HeaderEncoding.none}) {
    _part.addHeader(name, value, encoding);
  }

  /// Sets a header with the specified [name] and [value]
  ///
  /// This replaces any previous header with the same [name].
  ///
  /// Compare [MailConventions] for common header names.
  /// Set [encoding] to any of the [HeaderEncoding] formats to
  /// encode the header.
  void setHeader(String name, String? value,
      {HeaderEncoding encoding = HeaderEncoding.none}) {
    _part.setHeader(name, value, encoding);
  }

  /// Removes the header with the specified [name].
  ///
  /// Compare [MailConventions] for common header names.
  void removeHeader(String name) {
    _part.removeHeader(name);
  }

  /// Adds another header with the specified [name]
  ///
  /// with the given mail [addresses] as its value
  void addMailAddressHeader(String name, List<MailAddress> addresses) {
    addHeader(name, addresses.map((a) => a.encode()).join('; '));
  }

  /// Adds the header with the specified [name]
  ///
  /// with the given mail [addresses] as its value
  void setMailAddressHeader(String name, List<MailAddress> addresses) {
    setHeader(name, addresses.map((a) => a.encode()).join(', '));
  }

  void _buildPart() {
    final topMediaType = contentType?.mediaType.top;
    final addContentTransferEncodingHeader =
        topMediaType != MediaToptype.message &&
            topMediaType != MediaToptype.multipart;
    var partTransferEncoding = transferEncoding;
    if (addContentTransferEncodingHeader &&
        partTransferEncoding == TransferEncoding.automatic) {
      final messageText = text;
      if (messageText != null &&
          (contentType == null || contentType!.mediaType.isText)) {
        partTransferEncoding =
            MessageBuilder._contains8BitCharacters(messageText)
                ? TransferEncoding.quotedPrintable
                : TransferEncoding.sevenBit;
      } else {
        partTransferEncoding = TransferEncoding.base64;
      }
      transferEncoding = partTransferEncoding;
    }
    if (contentType == null) {
      if (_attachments.isNotEmpty) {
        setContentType(MediaSubtype.multipartMixed.mediaType,
            multiPartBoundary: MessageBuilder.createRandomId());
      } else if (_children == null || _children!.isEmpty) {
        setContentType(MediaSubtype.textPlain.mediaType);
      } else {
        setContentType(MediaSubtype.multipartMixed.mediaType,
            multiPartBoundary: MessageBuilder.createRandomId());
      }
    }
    if (contentType != null) {
      if (_attachments.isNotEmpty && contentType!.boundary == null) {
        contentType!.boundary = MessageBuilder.createRandomId();
      }
      setHeader(MailConventions.headerContentType, contentType!.render());
    }
    if (addContentTransferEncodingHeader) {
      setHeader(MailConventions.headerContentTransferEncoding,
          MessageBuilder.getContentTransferEncodingName(partTransferEncoding));
    }
    if (contentDisposition != null) {
      setHeader(MailConventions.headerContentDisposition,
          contentDisposition!.render());
    }
    // build body:
    final bodyText = text;
    if ((_part.mimeData == null) &&
        (bodyText != null) &&
        (_part.parts?.isEmpty ?? true)) {
      _part.mimeData = TextMimeData(
          MessageBuilder.encodeText(
              bodyText, transferEncoding, characterSet ?? CharacterSet.utf8),
          containsHeader: false);
      if (contentType == null) {
        setHeader(MailConventions.headerContentType,
            'text/plain; charset="${MessageBuilder.getCharacterSetName(characterSet)}"');
      }
    }
    _children?.forEach((c) => c._buildPart());
  }
}

/// Simplifies creating mime messages for sending or storing.
class MessageBuilder extends PartBuilder {
  /// Creates a new message builder and populates it with the optional data.
  ///
  /// Set the plain text part with [text] encoded with [transferEncoding]
  /// using the given [characterSet].
  ///
  /// You can also set the complete [contentType].
  /// Finally you can set the [subjectEncoding], defaulting to quoted printable.
  MessageBuilder({
    String? text,
    TransferEncoding transferEncoding = TransferEncoding.automatic,
    CharacterSet? characterSet,
    ContentTypeHeader? contentType,
    this.subjectEncoding = HeaderEncoding.Q,
  }) : super(MimeMessage(),
            text: text,
            transferEncoding: transferEncoding,
            characterSet: characterSet,
            contentType: contentType) {
    _message = _part as MimeMessage;
  }

  /// Prepares to create a reply to the given [originalMessage]
  /// to be send by the user specified in [from].
  ///
  /// Set [replyAll] to false in case the reply should only be done to the
  /// sender of the message and not to other recipients
  ///
  /// Set [quoteOriginalText] to true in case the original plain and html
  /// texts should be added to the generated message.
  ///
  /// Set [preferPlainText] and [quoteOriginalText] to true in case only
  /// plain text should be quoted.
  ///
  /// You can also specify a custom [replyHeaderTemplate], which is only used
  /// when [quoteOriginalText] has been set to true. The default
  /// replyHeaderTemplate is 'On <date> <from> wrote:'.
  ///
  /// Set [replyToSimplifyReferences] to true if the References field
  /// should not contain the references of all messages in this thread.
  ///
  /// Specify the [defaultReplyAbbreviation] if not 'Re' should be used at the
  /// beginning of the subject to indicate an reply.
  ///
  /// Specify the known [aliases] of the recipient, so that alias addresses are
  /// not added as recipients and a detected alias is used instead of the
  /// [from] address in that case.
  ///
  /// Set [handlePlusAliases] to true in case plus aliases like
  /// `email+alias@domain.com` should be detected and used.
  factory MessageBuilder.prepareReplyToMessage(
    MimeMessage originalMessage,
    MailAddress from, {
    bool replyAll = true,
    bool quoteOriginalText = false,
    bool preferPlainText = false,
    String replyHeaderTemplate = MailConventions.defaultReplyHeaderTemplate,
    String defaultReplyAbbreviation = MailConventions.defaultReplyAbbreviation,
    bool replyToSimplifyReferences = false,
    List<MailAddress>? aliases,
    bool handlePlusAliases = false,
    HeaderEncoding subjectEncoding = HeaderEncoding.Q,
  }) {
    String? subject;
    final originalSubject = originalMessage.decodeSubject();
    if (originalSubject != null) {
      subject = createReplySubject(originalSubject,
          defaultReplyAbbreviation: defaultReplyAbbreviation);
    }
    var to = originalMessage.to ?? [];
    var cc = originalMessage.cc;
    final replyTo = originalMessage.decodeSender();
    List<MailAddress> senders;
    if (aliases?.isNotEmpty ?? false) {
      senders = [from, ...aliases!];
    } else {
      senders = [from];
    }
    var newSender = MailAddress.getMatch(senders, replyTo,
        handlePlusAliases: handlePlusAliases,
        removeMatch: true,
        useMatchPersonalName: true);
    newSender ??= MailAddress.getMatch(senders, to,
        handlePlusAliases: handlePlusAliases, removeMatch: true);
    newSender ??= MailAddress.getMatch(senders, cc,
        handlePlusAliases: handlePlusAliases, removeMatch: true);
    if (replyAll) {
      to.insertAll(0, replyTo);
    } else {
      if (replyTo.isNotEmpty) {
        to = [...replyTo];
      }
      cc = null;
    }
    final builder = MessageBuilder()
      ..subject = subject
      ..subjectEncoding = subjectEncoding
      ..originalMessage = originalMessage
      ..from = [newSender ?? from]
      ..to = to
      ..cc = cc
      ..replyToSimplifyReferences = replyToSimplifyReferences;

    if (quoteOriginalText) {
      final replyHeader = fillTemplate(replyHeaderTemplate, originalMessage);

      final plainText = originalMessage.decodeTextPlainPart();
      final quotedPlainText = quotePlainText(replyHeader, plainText);
      final decodedHtml = originalMessage.decodeTextHtmlPart();
      if (preferPlainText || decodedHtml == null) {
        builder.text = quotedPlainText;
      } else {
        builder
          ..setContentType(MediaSubtype.multipartAlternative.mediaType)
          ..addTextPlain(quotedPlainText);
        final quotedHtml =
            '<blockquote><br/>$replyHeader<br/>$decodedHtml</blockquote>';
        builder.addTextHtml(quotedHtml);
      }
    }
    return builder;
  }

  /// Convenience method for initiating a multipart/alternative message
  ///
  /// In case you want to use 7bit instead of the default 8bit content transfer
  /// encoding, specify the optional [transferEncoding].
  ///
  /// You can also create a new MessageBuilder and call
  /// [setContentType] with the same effect when using the
  /// `multipart/alternative` media subtype.
  factory MessageBuilder.prepareMultipartAlternativeMessage({
    String? plainText,
    String? htmlText,
    TransferEncoding transferEncoding = TransferEncoding.eightBit,
  }) {
    final builder = MessageBuilder.prepareMessageWithMediaType(
      MediaSubtype.multipartAlternative,
      transferEncoding: transferEncoding,
    );
    if (plainText != null && htmlText != null) {
      builder
        ..addTextPlain(plainText)
        ..addTextHtml(htmlText);
    }
    return builder;
  }

  /// Convenience method for initiating a multipart/mixed message
  ///
  /// In case you want to use 7bit instead of the default 8bit content transfer
  /// encoding, specify the optional [transferEncoding].
  ///
  /// You can also create a new MessageBuilder and call [setContentType]
  /// with the same effect when using the multipart/mixed media subtype.
  factory MessageBuilder.prepareMultipartMixedMessage(
          {TransferEncoding transferEncoding = TransferEncoding.eightBit}) =>
      MessageBuilder.prepareMessageWithMediaType(MediaSubtype.multipartMixed,
          transferEncoding: transferEncoding);

  /// Convenience method to init a message with the specified media [subtype]
  ///
  /// In case you want to use 7bit instead of the default 8bit content transfer
  /// encoding, specify the optional [transferEncoding].
  ///
  /// You can also create a new MessageBuilder and call [setContentType]
  /// with the same effect when using the identical media subtype.
  factory MessageBuilder.prepareMessageWithMediaType(MediaSubtype subtype,
      {TransferEncoding transferEncoding = TransferEncoding.eightBit}) {
    final mediaType = subtype.mediaType;
    final builder = MessageBuilder()
      ..setContentType(mediaType)
      ..transferEncoding = transferEncoding;
    return builder;
  }

  /// Convenience method for creating a message based on a
  /// [mailto](https://tools.ietf.org/html/rfc6068) URI from
  /// the sender specified in [from].
  ///
  /// The following fields are supported:
  /// ```
  /// * mailto `to` recipient address(es)
  /// * `cc` - CC recipient address(es)
  /// * `subject` - the subject header field
  /// * `body` - the body header field
  /// * `in-reply-to` -  message ID to which the new message is a reply
  /// ```
  factory MessageBuilder.prepareMailtoBasedMessage(
      Uri mailto, MailAddress from) {
    final builder = MessageBuilder()
      ..from = [from]
      ..setContentType(MediaType.textPlain, characterSet: CharacterSet.utf8)
      ..transferEncoding = TransferEncoding.automatic;
    final to = <MailAddress>[];
    for (final value in mailto.pathSegments) {
      to.addAll(value.split(',').map((email) => MailAddress(null, email)));
    }
    final queryParameters = mailto.queryParameters;
    for (final key in queryParameters.keys) {
      final value = queryParameters[key];
      switch (key.toLowerCase()) {
        case 'subject':
          builder.subject = value;
          // Defaults to QP-encoding
          builder.subjectEncoding = HeaderEncoding.Q;
          break;
        case 'to':
          to.addAll(value!.split(',').map((email) => MailAddress(null, email)));
          break;
        case 'cc':
          builder.cc = value!
              .split(',')
              .map((email) => MailAddress(null, email))
              .toList();
          break;
        case 'body':
          builder.text = value;
          break;
        case 'in-reply-to':
          builder.setHeader(key, value);
          break;
        default:
          print('unsupported mailto parameter $key=$value');
      }
    }
    builder.to = to;
    return builder;
  }

  /// Prepares a message builder from the specified [draft] mime message.
  factory MessageBuilder.prepareFromDraft(MimeMessage draft) {
    final builder = MessageBuilder()
      ..originalMessage = draft
      .._copy(draft);
    return builder;
  }

  /// Prepares to forward the given [originalMessage].
  ///
  /// Optionally specify the sending user with [from].
  ///
  /// You can also specify a custom [forwardHeaderTemplate]. The default
  /// `MailConventions.defaultForwardHeaderTemplate` contains the metadata
  /// information about the original message including subject, to, cc, date.
  ///
  /// Specify the [defaultForwardAbbreviation] if not `Fwd` should be used at
  /// the beginning of the subject to indicate an reply.
  ///
  /// Set [quoteMessage] to `false` when you plan to quote text yourself,
  /// e.g. using the `enough_mail_html`'s package `quoteToHtml()` method.
  ///
  /// Set [forwardAttachments] to `false` when parts with a content-disposition
  /// of attachment should not be forwarded.
  factory MessageBuilder.prepareForwardMessage(
    MimeMessage originalMessage, {
    MailAddress? from,
    String forwardHeaderTemplate = MailConventions.defaultForwardHeaderTemplate,
    String defaultForwardAbbreviation =
        MailConventions.defaultForwardAbbreviation,
    bool quoteMessage = true,
    HeaderEncoding subjectEncoding = HeaderEncoding.Q,
    bool forwardAttachments = true,
  }) {
    String subject;
    final originalSubject = originalMessage.decodeSubject();
    if (originalSubject != null) {
      subject = createForwardSubject(originalSubject,
          defaultForwardAbbreviation: defaultForwardAbbreviation);
    } else {
      subject = defaultForwardAbbreviation;
    }

    final builder = MessageBuilder()
      ..subject = subject
      ..subjectEncoding = subjectEncoding
      ..contentType = originalMessage.getHeaderContentType()
      ..transferEncoding = _getTransferEncoding(originalMessage)
      ..originalMessage = originalMessage;
    if (from != null) {
      builder.from = [from];
    }
    if (quoteMessage) {
      final forwardHeader =
          fillTemplate(forwardHeaderTemplate, originalMessage);
      if (originalMessage.parts?.isNotEmpty ?? false) {
        var processedTextPlainPart = false;
        var processedTextHtmlPart = false;
        for (final part in originalMessage.parts!) {
          if (part.isTextMediaType()) {
            if (!processedTextPlainPart &&
                part.mediaType.sub == MediaSubtype.textPlain) {
              final plainText = part.decodeContentText();
              final quotedPlainText = quotePlainText(forwardHeader, plainText);
              builder.addTextPlain(quotedPlainText);
              processedTextPlainPart = true;
              continue;
            }
            if (!processedTextHtmlPart &&
                part.mediaType.sub == MediaSubtype.textHtml) {
              final decodedHtml = part.decodeContentText() ?? '';
              final quotedHtml = '<br/><blockquote>${forwardHeader.split(
                    '\r\n',
                  ).join(
                    '<br/>\r\n',
                  )}<br/>\r\n$decodedHtml</blockquote>';
              builder.addTextHtml(quotedHtml);
              processedTextHtmlPart = true;
              continue;
            }
          }
          if (forwardAttachments ||
              part.getHeaderContentDisposition()?.disposition !=
                  ContentDisposition.attachment) {
            builder.addPart(mimePart: part);
          }
        }
      } else {
        // no parts, this is most likely a plain text message:
        if (originalMessage.isTextPlainMessage()) {
          final plainText = originalMessage.decodeContentText();
          final quotedPlainText = quotePlainText(forwardHeader, plainText);
          builder.text = quotedPlainText;
        } else {
          //TODO check if there is anything else to quote
        }
      }
    } else if (forwardAttachments) {
      // do not quote message but forward attachments
      final infos = originalMessage.findContentInfo();
      for (final info in infos) {
        final part = originalMessage.getPart(info.fetchId);
        if (part != null) {
          builder.addPart(mimePart: part);
        }
      }
    }

    return builder;
  }

  late MimeMessage _message;

  /// List of senders, typically this is only one sender
  List<MailAddress>? from;

  /// One sender in case there are different `from` senders
  MailAddress? sender;

  /// `to` recipients
  List<MailAddress>? to;

  /// `cc` recipients
  List<MailAddress>? cc;

  /// `bcc` recipients
  List<MailAddress>? bcc;

  /// Message subject
  String? subject;

  /// Header encoding type
  HeaderEncoding subjectEncoding;

  /// Message date
  DateTime? date;

  /// ID of the message
  String? messageId;

  /// Reference to original message
  MimeMessage? originalMessage;

  /// Set to `true` in case only the last replied to message should
  /// be referenced. Useful for long threads.
  bool replyToSimplifyReferences = false;

  /// Set to `true` to set chat headers
  bool isChat = false;

  /// Specify in case this is a chat group discussion
  String? chatGroupId;

  @override
  void _copy(MimePart originalPart) {
    final originalMessage = originalPart as MimeMessage;
    characterSet = CharacterSet.utf8;
    to = originalMessage.to;
    cc = originalMessage.cc;
    bcc = originalMessage.bcc;
    subject = originalMessage.decodeSubject();
    super._copy(originalPart);
  }

  /// Adds a [recipient].
  ///
  /// Specify the [group] in case the recipient should not be added
  /// to the 'To' group.
  /// Compare [removeRecipient] and [clearRecipients].
  void addRecipient(MailAddress recipient,
      {RecipientGroup group = RecipientGroup.to}) {
    switch (group) {
      case RecipientGroup.to:
        to ??= <MailAddress>[];
        to!.add(recipient);
        break;
      case RecipientGroup.cc:
        cc ??= <MailAddress>[];
        cc!.add(recipient);
        break;
      case RecipientGroup.bcc:
        bcc ??= <MailAddress>[];
        bcc!.add(recipient);
        break;
    }
  }

  /// Removes the specified [recipient] from To/Cc/Bcc fields.
  ///
  /// Compare [addRecipient] and [clearRecipients].
  void removeRecipient(MailAddress recipient) {
    if (to != null) {
      to!.remove(recipient);
    }
    if (cc != null) {
      cc!.remove(recipient);
    }
    if (bcc != null) {
      bcc!.remove(recipient);
    }
  }

  /// Removes all recipients from this message.
  ///
  /// Compare [removeRecipient] and [addRecipient].
  void clearRecipients() {
    to = null;
    cc = null;
    bcc = null;
  }

  /// Sets the transfer encoding to the recommended one.
  ///
  /// Set [supports8BitMessages] to `true` in case 8-bit message transfer
  /// is supported by the provider.
  TransferEncoding setRecommendedTextEncoding({
    bool supports8BitMessages = false,
  }) {
    var recommendedEncoding = TransferEncoding.quotedPrintable;
    final textHtml = getTextHtmlPart();
    final textPlain = getTextPlainPart();
    if (!supports8BitMessages) {
      if (_contains8BitCharacters(text) ||
          _contains8BitCharacters(textPlain?.text) ||
          _contains8BitCharacters(textHtml?.text)) {
        recommendedEncoding = TransferEncoding.quotedPrintable;
      } else {
        recommendedEncoding = TransferEncoding.sevenBit;
      }
    }
    transferEncoding = recommendedEncoding;
    textHtml?.transferEncoding = recommendedEncoding;
    textPlain?.transferEncoding = recommendedEncoding;
    return recommendedEncoding;
  }

  static bool _contains8BitCharacters(String? text) {
    if (text == null) {
      return false;
    }
    return text.runes.any((rune) => rune >= 127);
  }

  /// Requests a read receipt
  ///
  /// This is done by setting the `Disposition-Notification-To`
  /// header to from address.
  ///
  /// Optionally specify a [recipient] address when no message sender
  /// is defined in the [from] field yet.
  ///
  /// Compare [removeReadReceiptRequest]
  /// Compare [setHeader]
  void requestReadReceipt({MailAddress? recipient}) {
    recipient ??= (from?.isNotEmpty ?? false) ? from!.first : null;
    if (recipient == null) {
      throw InvalidArgumentException(
          'Either define a sender in from or specify the recipient parameter');
    }
    setHeader(MailConventions.headerDispositionNotificationTo, recipient.email);
  }

  /// Removes the read receipt request.
  ///
  /// Shortcut to
  /// `removeHeader(MailConventions.headerDispositionNotificationTo)`.
  /// Compare [requestReadReceipt]
  /// Compare [removeHeader]
  void removeReadReceiptRequest() {
    removeHeader(MailConventions.headerDispositionNotificationTo);
  }

  /// Creates the mime message based on the previous input.
  MimeMessage buildMimeMessage() {
    // there are not mandatory fields required in case only a Draft message
    // should be stored, for example

    // set default values for standard headers:
    date ??= DateTime.now();
    messageId ??= createMessageId(
        (from?.isEmpty ?? true) ? 'enough.de' : from!.first.hostName,
        isChat: isChat,
        chatGroupId: chatGroupId);
    if (subject == null && originalMessage != null) {
      final originalSubject = originalMessage!.decodeSubject();
      if (originalSubject != null) {
        subject = createReplySubject(originalSubject);
      }
    }
    if (from != null) {
      setMailAddressHeader('From', from!);
    }
    if (sender != null) {
      setMailAddressHeader('Sender', [sender!]);
    }
    var addresses = to;
    if (addresses != null && addresses.isNotEmpty) {
      setMailAddressHeader('To', addresses);
    }
    addresses = cc;
    if (addresses != null && addresses.isNotEmpty) {
      setMailAddressHeader('Cc', addresses);
    }
    addresses = bcc;
    if (addresses != null && addresses.isNotEmpty) {
      setMailAddressHeader('Bcc', addresses);
    }
    setHeader('Date', DateCodec.encodeDate(date!));
    setHeader('Message-Id', messageId);
    if (isChat) {
      setHeader('Chat-Version', '1.0');
    }
    if (subject != null) {
      setHeader('Subject', subject, encoding: subjectEncoding);
    }
    setHeader(MailConventions.headerMimeVersion, '1.0');
    final original = originalMessage;
    if (original != null) {
      final originalMessageId = original.getHeaderValue('message-id');
      setHeader(MailConventions.headerInReplyTo, originalMessageId);
      final originalReferences = original.getHeaderValue('references');
      final references = originalReferences == null
          ? originalMessageId
          : replyToSimplifyReferences
              ? originalReferences
              : '$originalReferences $originalMessageId';
      setHeader(MailConventions.headerReferences, references);
    }
    if (text != null && _attachments.isNotEmpty) {
      addTextPlain(text!, transferEncoding: transferEncoding, insert: true);
    }
    _buildPart();
    _message.parse();
    return _message;
  }

  /// Creates a text message.
  ///
  /// [from] the mandatory originator of the message
  ///
  /// [to] the mandatory list of recipients
  ///
  /// [text] the mandatory content of the message
  ///
  /// [cc] the optional "carbon copy" recipients that are informed
  /// about this message
  ///
  /// [bcc] the optional "blind carbon copy" recipients that should receive
  /// the message without others being able to see those recipients
  ///
  /// [subject] the optional subject of the message, if null and a
  /// [replyToMessage] is specified, then the subject of that message is
  ///  being re-used.
  ///
  /// [subjectEncoding] the optional subject [HeaderEncoding] format
  ///
  /// [date] the optional date of the message, is set to DateTime.now()
  /// by default
  ///
  /// [replyToMessage] is the message that this message is a reply to
  ///
  /// Set the optional [replyToSimplifyReferences] parameter to `true` in
  /// case only the root message-ID should be repeated instead of all
  /// references as calculated from the [replyToMessage]
  ///
  /// [messageId] the optional custom message ID
  ///
  /// Set the optional [isChat] to true in case a COI-compliant message ID
  /// should be generated, in case of a group message also specify
  /// the [chatGroupId].
  ///
  /// [chatGroupId] the optional ID of the chat group in case the
  /// message-ID should be generated.
  ///
  /// [characterSet] the optional character set, defaults to [CharacterSet.utf8]
  ///
  /// [transferEncoding] the optional message encoding, defaults to
  /// [TransferEncoding.quotedPrintable]
  static MimeMessage buildSimpleTextMessage(
    MailAddress from,
    List<MailAddress> to,
    String text, {
    List<MailAddress>? cc,
    List<MailAddress>? bcc,
    String? subject,
    HeaderEncoding subjectEncoding = HeaderEncoding.Q,
    DateTime? date,
    MimeMessage? replyToMessage,
    bool replyToSimplifyReferences = false,
    String? messageId,
    bool isChat = false,
    String? chatGroupId,
    CharacterSet characterSet = CharacterSet.utf8,
    TransferEncoding transferEncoding = TransferEncoding.quotedPrintable,
  }) {
    final builder = MessageBuilder()
      ..from = [from]
      ..to = to
      ..subject = subject
      ..subjectEncoding = subjectEncoding
      ..text = text
      ..cc = cc
      ..bcc = bcc
      ..date = date
      ..originalMessage = replyToMessage
      ..replyToSimplifyReferences = replyToSimplifyReferences
      ..messageId = messageId
      ..isChat = isChat
      ..chatGroupId = chatGroupId
      ..characterSet = characterSet
      ..transferEncoding = transferEncoding;

    return builder.buildMimeMessage();
  }

  static TransferEncoding _getTransferEncoding(MimeMessage originalMessage) {
    final originalTransferEncoding = originalMessage
        .getHeaderValue(MailConventions.headerContentTransferEncoding);
    return originalTransferEncoding == null
        ? TransferEncoding.automatic
        : fromContentTransferEncodingName(originalTransferEncoding);
  }

  /// Builds a disposition notification report for the given [originalMessage]
  ///
  /// that has been received by the [finalRecipient].
  ///
  /// Optionally specify the reporting user agent, ie your apps name with the
  /// [reportingUa] parameter, e.g. `'My Mail App 1.0'`.
  ///
  /// Optionally specify that the report is generated automatically by setting
  /// [isAutomaticReport] to `true` - this defaults to `false`.
  ///
  /// Optionally specify a [subject], this defaults to `'read receipt'`.
  ///
  /// Optionally specify your own [textTemplate] in which  you can use the
  /// fields `<subject>`, `<date>`, `<recipient>` and `<sender>`.
  /// This defaults to [MailConventions.defaultReadReceiptTemplate].
  ///
  /// Throws a [InvalidArgumentException] when the originalMessage has no valid
  /// `Disposition-Notification-To` or `Return-Receipt-To` header.
  ///
  /// Use [requestReadReceipt] to request a read receipt when building a
  /// message.
  static MimeMessage buildReadReceipt(
    MimeMessage originalMessage,
    MailAddress finalRecipient, {
    String reportingUa = 'enough_mail',
    bool isAutomaticReport = false,
    String subject = 'read receipt',
    String textTemplate = MailConventions.defaultReadReceiptTemplate,
  }) {
    final builder = MessageBuilder();
    var recipient = originalMessage.decodeHeaderMailAddressValue(
        MailConventions.headerDispositionNotificationTo);
    if (recipient == null || recipient.isEmpty) {
      recipient =
          originalMessage.decodeHeaderMailAddressValue('Return-Receipt-To');
      if (recipient == null || recipient.isEmpty) {
        throw InvalidArgumentException(
            'Invalid header ${MailConventions.headerDispositionNotificationTo} '
            'in message: '
            '${originalMessage.getHeaderValue(
          MailConventions.headerDispositionNotificationTo,
        )}');
      }
    }
    builder
      ..subject = subject
      ..to = recipient
      ..setContentType(MediaSubtype.multipartReport.mediaType);
    final parameters = <String, String>{
      'recipient': finalRecipient.toString(),
      'sender': originalMessage.fromEmail ?? '<unknown>',
    };
    builder.setHeader(MailConventions.headerMimeVersion, '1.0');
    final plainText =
        fillTemplate(textTemplate, originalMessage, parameters: parameters);
    builder.addTextPlain(plainText);
    final mdnPart = builder.addPart(
        mediaSubtype: MediaSubtype.messageDispositionNotification)
      ..transferEncoding = TransferEncoding.sevenBit
      ..contentDisposition = ContentDispositionHeader.inline();
    final buffer = StringBuffer()
      ..write('Reporting-UA: ')
      ..write(reportingUa)
      ..write('\r\n');
    if (originalMessage.findRecipient(finalRecipient) != null) {
      buffer
        ..write('Original-Recipient: rfc822;')
        ..write(finalRecipient.email)
        ..write('\r\n');
    }
    buffer
      ..write('Final-Recipient: rfc822;')
      ..write(finalRecipient.email)
      ..write('\r\n')
      ..write('Original-Message-ID: ')
      ..write(originalMessage.getHeaderValue(MailConventions.headerMessageId))
      ..write('\r\n');
    if (isAutomaticReport) {
      buffer.write(
          'Disposition: automatic-action/MDN-sent-automatically; displayed\r\n');
    } else {
      buffer
          .write('Disposition: manual-action/MDN-sent-manually; displayed\r\n');
    }
    mdnPart.text = buffer.toString();
    builder.from = [finalRecipient];
    return builder.buildMimeMessage();
  }

  /// Quotes the given plain text [header] and [text].
  static String quotePlainText(final String header, final String? text) {
    if (text == null) {
      return '>\r\n';
    }
    return '>${header.split(
          '\r\n',
        ).join(
          '\r\n>',
        )}\r\n>${text.split(
          '\r\n',
        ).join('\r\n>')}';
  }

  /// Generates a message ID
  ///
  /// [hostName] the domain like 'example.com'
  ///
  /// Set the optional [isChat] to true in case a COI-compliant message ID
  /// should be generated, in case of a group message also specify the
  /// [chatGroupId].
  ///
  /// [chatGroupId] the optional ID of the chat group in case the message-ID
  /// should be generated.
  static String createMessageId(String? hostName,
      {bool isChat = false, String? chatGroupId}) {
    String id;
    final random = createRandomId();
    if (isChat) {
      if (chatGroupId != null && chatGroupId.isNotEmpty) {
        id = '<chat\$group.$chatGroupId.$random@$hostName>';
      } else {
        id = '<chat\$$random@$hostName>';
      }
    } else {
      id = '<$random@$hostName>';
    }
    return id;
  }

  /// Encodes the specified [text] with given [transferEncoding].
  ///
  /// Specify the [characterSet] when a different character set than `UTF-8`
  /// should be used.
  static String encodeText(String text, TransferEncoding transferEncoding,
      [CharacterSet characterSet = CharacterSet.utf8]) {
    switch (transferEncoding) {
      case TransferEncoding.quotedPrintable:
        return MailCodec.quotedPrintable
            .encodeText(text, codec: getCodec(characterSet));
      case TransferEncoding.base64:
        return MailCodec.base64.encodeText(text, codec: getCodec(characterSet));
      default:
        return MailCodec.wrapText(text, wrapAtWordBoundary: true);
    }
  }

  /// Retrieves the codec for the specified [characterSet].
  static Codec getCodec(CharacterSet? characterSet) {
    switch (characterSet) {
      case null:
        return utf8;
      case CharacterSet.ascii:
        return ascii;
      case CharacterSet.utf8:
        return utf8;
      case CharacterSet.latin1:
        return latin1;
    }
  }

  /// Encodes the specified header [value].
  ///
  /// Specify the [transferEncoding] when not the default `quoted-printable`
  /// transfer encoding should be used.
  static String encodeHeaderValue(String value,
      [TransferEncoding transferEncoding = TransferEncoding.quotedPrintable]) {
    switch (transferEncoding) {
      case TransferEncoding.quotedPrintable:
        return MailCodec.quotedPrintable.encodeHeader(value);
      case TransferEncoding.base64:
        return MailCodec.base64.encodeHeader(value);
      default:
        return value;
    }
  }

  /// Retrieves the name of the specified [characterSet].
  static String getCharacterSetName(CharacterSet? characterSet) {
    switch (characterSet) {
      case null:
        return 'utf-8';
      case CharacterSet.utf8:
        return 'utf-8';
      case CharacterSet.ascii:
        return 'ascii';
      case CharacterSet.latin1:
        return 'latin1';
    }
  }

  /// Retrieves the name of the specified [encoding].
  ///
  /// Throws an [InvalidArgumentException] when the encoding is not yet handled.
  static String getContentTransferEncodingName(TransferEncoding encoding) {
    switch (encoding) {
      case TransferEncoding.sevenBit:
        return '7bit';
      case TransferEncoding.eightBit:
        return '8bit';
      case TransferEncoding.quotedPrintable:
        return 'quoted-printable';
      case TransferEncoding.base64:
        return 'base64';
      default:
        throw InvalidArgumentException(
            'Unhandled transfer encoding: $encoding');
    }
  }

  /// Detects the transfer encoding from the given [name].
  static TransferEncoding fromContentTransferEncodingName(String name) {
    switch (name.toLowerCase()) {
      case '7bit':
        return TransferEncoding.sevenBit;
      case '8bit':
        return TransferEncoding.eightBit;
      case 'quoted-printable':
        return TransferEncoding.quotedPrintable;
      case 'base64':
        return TransferEncoding.base64;
    }
    return TransferEncoding.automatic;
  }

  /// Creates a subject based on the [originalSubject]
  /// taking mail conventions into account.
  ///
  /// Optionally specify the reply-indicator abbreviation by specifying
  /// [defaultReplyAbbreviation], which defaults to 'Re'.
  static String createReplySubject(String originalSubject,
          {String defaultReplyAbbreviation =
              MailConventions.defaultReplyAbbreviation}) =>
      _createSubject(originalSubject, defaultReplyAbbreviation,
          MailConventions.subjectReplyAbbreviations);

  /// Creates a subject based on the [originalSubject]
  /// taking mail conventions into account.
  ///
  /// Optionally specify the forward-indicator abbreviation by specifying
  /// [defaultForwardAbbreviation], which defaults to 'Fwd'.
  static String createForwardSubject(String originalSubject,
          {String defaultForwardAbbreviation =
              MailConventions.defaultForwardAbbreviation}) =>
      _createSubject(originalSubject, defaultForwardAbbreviation,
          MailConventions.subjectForwardAbbreviations);

  /// Creates a subject based on the [originalSubject]
  /// taking mail conventions into account.
  ///
  /// Optionally specify the reply-indicator abbreviation by specifying
  /// [defaultAbbreviation], which defaults to 'Re'.
  static String _createSubject(String originalSubject,
      String defaultAbbreviation, List<String> commonAbbreviations) {
    final colonIndex = originalSubject.indexOf(':');
    if (colonIndex != -1) {
      var start = originalSubject.substring(0, colonIndex);
      if (commonAbbreviations.contains(start)) {
        // the original subject already contains a common reply abbreviation,
        //e.g. 'Re: bla'
        return originalSubject;
      }
      // some mail servers use rewrite rules to adapt the subject,
      //e.g start each external messages with '[EXT]'
      final prefixStartIndex = originalSubject.indexOf('[');
      if (prefixStartIndex == 0) {
        final prefixEndIndex = originalSubject.indexOf(']');
        if (prefixEndIndex < colonIndex) {
          start = start.substring(prefixEndIndex + 1).trim();
          if (commonAbbreviations.contains(start)) {
            // the original subject already contains a common reply
            // abbreviation, e.g. 'Re: bla'
            return originalSubject.substring(prefixEndIndex + 1).trim();
          }
        }
      }
    }
    return '$defaultAbbreviation: $originalSubject';
  }

  /// Creates a new randomized ID text.
  ///
  /// Specify [length] when a different length than 18 characters
  /// should be used.
  ///
  /// This can be used as a multipart boundary or a message-ID, for example.
  static String createRandomId({int length = 18}) {
    const characters =
        '0123456789_abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final characterRunes = characters.runes;
    const max = characters.length;
    final random = math.Random();
    final buffer = StringBuffer();
    for (var count = length; count > 0; count--) {
      final charIndex = random.nextInt(max);
      final rune = characterRunes.elementAt(charIndex);
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// Fills the given [template] with values
  /// extracted from the provided [message].
  ///
  /// Optionally extends the template fields by defining them in the
  /// [parameters] field.
  ///
  /// Currently the following templates are supported:
  /// ```
  ///  `<from>`: specifies the message sender (name plus email)
  ///  `<date>`: specifies the message date
  ///  `<to>`: the `to` recipients
  ///  `<cc>`: the `cc` recipients
  ///  `<subject>`: the subject of the message
  /// ```
  /// Note that for date formatting Dart's
  /// [intl](https://pub.dev/packages/intl) library is used.
  ///
  /// You might want to specify the default locale by setting
  /// [Intl.defaultLocale] first.
  static String fillTemplate(
    String template,
    MimeMessage message, {
    Map<String, String>? parameters,
  }) {
    final definedVariables = <String>[];
    var result = template;
    var from = message.decodeHeaderMailAddressValue('sender');
    if (from?.isEmpty ?? true) {
      from = message.decodeHeaderMailAddressValue('from');
    }
    if (from?.isNotEmpty ?? false) {
      definedVariables.add('from');
      result = result.replaceAll('<from>', from!.first.toString());
    }
    final date = message.decodeHeaderDateValue('date');
    if (date != null) {
      definedVariables.add('date');
      final dateStr = DateFormat.yMd().add_jm().format(date);
      result = result.replaceAll('<date>', dateStr);
    }
    final to = message.to;
    if (to?.isNotEmpty ?? false) {
      definedVariables.add('to');
      result = result.replaceAll('<to>', _renderAddresses(to!));
    }
    final cc = message.cc;
    if (cc?.isNotEmpty ?? false) {
      definedVariables.add('cc');
      result = result.replaceAll('<cc>', _renderAddresses(cc!));
    }
    final subject = message.decodeSubject();
    if (subject != null) {
      definedVariables.add('subject');
      result = result.replaceAll('<subject>', subject);
    }
    if (parameters != null) {
      for (final key in parameters.keys) {
        definedVariables.add(key);
        result = result.replaceAll('<$key>', parameters[key]!);
      }
    }
    // remove any undefined variables from result:
    final optionalInclusionsExpression = RegExp(r'\[\[\w+\s[\s\S]+?\]\]');
    RegExpMatch? match;
    while ((match = optionalInclusionsExpression.firstMatch(result)) != null) {
      final sequence = match!.group(0)!;
      //print('sequence=$sequence');
      final separatorIndex = sequence.indexOf(' ', 2);
      final name = sequence.substring(2, separatorIndex);
      var replacement = '';
      if (definedVariables.contains(name)) {
        replacement =
            sequence.substring(separatorIndex + 1, sequence.length - 2);
      }
      result = result.replaceAll(sequence, replacement);
    }
    return result;
  }

  static String _renderAddresses(List<MailAddress> addresses) {
    final buffer = StringBuffer();
    var addDelimiter = false;
    for (final address in addresses) {
      if (addDelimiter) {
        buffer.write('; ');
      }
      address.writeToStringBuffer(buffer);
      addDelimiter = true;
    }
    return buffer.toString();
  }
}
