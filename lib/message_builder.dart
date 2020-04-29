import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:enough_mail/codecs/date_codec.dart';
import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/mail_conventions.dart';
import 'package:enough_mail/media_type.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:intl/intl.dart';

enum MessageEncoding { sevenBit, eightBit, quotedPrintable, base64 }

enum CharacterSet { ascii, utf8, latin1 }

enum RecipientGroup { to, cc, bcc }

class PartBuilder {
  String text;
  MessageEncoding encoding;
  CharacterSet characterSet;
  ContentTypeHeader contentType;
  String contentTransferEncoding;

  final MimePart _part;
  List<PartBuilder> _children;

  ContentDispositionHeader contentDisposition;

  PartBuilder(this._part);

  /// Creates the content-type based on the specified [mediaType].
  /// Optionally you can specify the [characterSet], [multiPartBoundary] or other [parameters].
  void setContentType(MediaType mediaType,
      {CharacterSet characterSet,
      String multiPartBoundary,
      Map<String, String> parameters}) {
    if (mediaType.isMultipart && multiPartBoundary == null) {
      multiPartBoundary = MessageBuilder.createRandomId();
    }
    contentType = ContentTypeHeader.from(mediaType,
        charset: MessageBuilder.getCharacterSetName(characterSet),
        boundary: multiPartBoundary);
    if (parameters?.isNotEmpty ?? false) {
      contentType.parameters.addAll(parameters);
    }
  }

  /// Adds a text part to this message with the specified [text].
  /// Specify the optional [mediaType], in case this is not a text/plain message
  /// and the [characterSet] in case it is not utf8.
  /// Optionally specify the content disposition with [disposition].
  PartBuilder addText(String text,
      {MediaType mediaType,
      MessageEncoding encoding,
      CharacterSet characterSet = CharacterSet.utf8,
      ContentDispositionHeader disposition}) {
    mediaType ??= MediaType.fromSubtype(MediaSubtype.textPlain);
    var child = addPart();
    child.setContentType(mediaType, characterSet: characterSet);
    child.encoding = encoding;
    child.contentDisposition = disposition;
    child.text = text;
    return child;
  }

  /// Adds a plain text part
  /// Compare [addText()] for details.
  PartBuilder addPlainText(String text,
      {MessageEncoding encoding,
      CharacterSet characterSet = CharacterSet.utf8,
      ContentDispositionHeader disposition}) {
    return addText(text,
        encoding: encoding,
        characterSet: characterSet,
        disposition: disposition);
  }

  /// Adds a HTML text part
  /// Compare [addText()] for details.
  PartBuilder addHtmlText(String text,
      {MessageEncoding encoding,
      CharacterSet characterSet = CharacterSet.utf8,
      ContentDispositionHeader disposition}) {
    return addText(text,
        mediaType: MediaType.fromSubtype(MediaSubtype.textHtml),
        encoding: encoding,
        characterSet: characterSet,
        disposition: disposition);
  }

  /// Adds a new part
  /// Specifiy the optional [disposition] in case you want to specify the content-disposition
  /// Optionally specify the [mimePart], if it is already
  PartBuilder addPart(
      {ContentDispositionHeader disposition, MimePart mimePart}) {
    mimePart ??= MimePart();
    _part.addPart(mimePart);
    var childBuilder = PartBuilder(mimePart);
    _children ??= <PartBuilder>[];
    _children.add(childBuilder);
    disposition ??= mimePart.getHeaderContentDisposition();
    childBuilder.contentDisposition = disposition;
    if (mimePart.isTextMediaType()) {
      childBuilder.text = mimePart.decodeContentText();
    }
    return childBuilder;
  }

  /// Retrieves the first builder with a text/plain part.
  /// Note that only this builder and direct children are queried.
  PartBuilder getTextPlainPart() {
    return getPart(MediaSubtype.textPlain);
  }

  /// Retrieves the first builder with a text/plain part.
  /// Note that only this builder and direct children are queried.
  PartBuilder getTextHtmlPart() {
    return getPart(MediaSubtype.textHtml);
  }

  /// Retrieves the first builder with the specified [mediaSubtype].
  /// Note that only this builder and direct children are queried.
  PartBuilder getPart(MediaSubtype mediaSubtype) {
    var isPlainText = (mediaSubtype == MediaSubtype.textPlain);
    if (_children?.isEmpty ?? true) {
      if (contentType?.mediaType?.sub == mediaSubtype ||
          (isPlainText && contentType == null)) {
        return this;
      }
      return null;
    }
    for (var child in _children) {
      if ((isPlainText && child.contentType == null) ||
          child.contentType?.mediaType?.sub == mediaSubtype) {
        return child;
      }
    }
    return null;
  }

  /// Removes the specified part
  void removePart(PartBuilder childBuilder) {
    _part.parts.remove(childBuilder._part);
    _children.remove(childBuilder);
  }

  /// Adds a file part aysncronously.
  /// [file] The file that should be added.
  /// [mediaType] The media type of the file.
  /// Specify the optional [encoding] if you do not want to use base64 content-transfer encoding.
  /// Specify the optional content [disposition] element, if it should not be populated automatically.
  Future<PartBuilder> addFile(File file, MediaType mediaType,
      {MessageEncoding encoding = MessageEncoding.base64,
      ContentDispositionHeader disposition}) async {
    disposition ??=
        ContentDispositionHeader.from(ContentDisposition.attachment);
    disposition.filename ??= _getFileName(file);
    disposition.size ??= await file.length();
    disposition.modificationDate ??= await file.lastModified();
    var child = addPart(disposition: disposition);
    var data = await file.readAsBytes();
    child.encoding = encoding;
    child.contentTransferEncoding =
        MessageBuilder.getContentTransferEncodingName(encoding);
    child.setContentType(mediaType);
    child._part.bodyRaw = MailCodec.base64.encodeData(data);
    return child;
  }

  String _getFileName(File file) {
    var name = file.path;
    var lastPathSeparator =
        math.max(name.lastIndexOf('/'), name.lastIndexOf('\\'));
    if (lastPathSeparator != -1 && lastPathSeparator != name.length - 1) {
      name = name.substring(lastPathSeparator + 1);
    }
    return name;
  }

  /// Adds a binary data part.
  /// [data] The data that should be added.
  /// [mediaType] The media type of the file.
  /// Specify the optional [encoding] if you do not want to use base64 content-transfer encoding.
  /// Specify the optional content [disposition] element, if it should not be populated automatically.
  PartBuilder addBinary(Uint8List data, MediaType mediaType,
      {MessageEncoding encoding = MessageEncoding.base64,
      ContentDispositionHeader disposition}) {
    disposition ??=
        ContentDispositionHeader.from(ContentDisposition.attachment);
    var child = addPart(disposition: disposition);
    child.encoding = encoding;
    child.contentTransferEncoding =
        MessageBuilder.getContentTransferEncodingName(encoding);
    child.setContentType(mediaType);
    child._part.bodyRaw = MailCodec.base64.encodeData(data);
    return child;
  }

  /// Adds a header with the specified [name] and [value].
  /// Compare [MailConventions] for common header names.
  /// Set [encode] to true to encode the header value in quoted printable format.
  void addHeader(String name, String value, {bool encode = false}) {
    if (encode) {
      value = MailCodec.quotedPrintable.encodeHeader(value);
    }
    _part.addHeader(name, value);
  }

  /// Sets a header with the specified [name] and [value], replacing any previous header with the same [name].
  /// Compare [MailConventions] for common header names.
  /// Set [encode] to true to encode the header value in quoted printable format.
  void setHeader(String name, String value, {bool encode = false}) {
    if (encode) {
      value = MailCodec.quotedPrintable.encodeHeader(value);
    }
    _part.setHeader(name, value);
  }

  void _buildPart() {
    if (contentType != null) {
      setHeader(MailConventions.headerContentType, contentType.render());
      _part.multiPartBoundary ??= contentType.boundary;
    }
    if (contentTransferEncoding != null) {
      setHeader(MailConventions.headerContentTransferEncoding,
          contentTransferEncoding);
    }
    if (contentDisposition != null) {
      setHeader(MailConventions.headerContentDisposition,
          contentDisposition.render());
    }
    // build body:
    if (text != null && (_part.parts?.isEmpty ?? true)) {
      _part.bodyRaw = MessageBuilder.encodeText(text, encoding, characterSet);
      if (contentType == null) {
        setHeader(MailConventions.headerContentType,
            'text/plain; charset="${MessageBuilder.getCharacterSetName(characterSet)}"');
      }
      if (contentTransferEncoding == null) {
        setHeader(MailConventions.headerContentTransferEncoding,
            MessageBuilder.getContentTransferEncodingName(encoding));
      }
    }
    if (_children != null && _children.isNotEmpty) {
      for (var child in _children) {
        child._buildPart();
      }
    }
  }
}

/// Simplifies creating mime messages for sending or storing.
class MessageBuilder extends PartBuilder {
  MimeMessage _message;

  List<MailAddress> from;
  MailAddress sender;
  List<MailAddress> to;
  List<MailAddress> cc;
  List<MailAddress> bcc;
  String subject;
  DateTime date;
  String messageId;
  MimeMessage replyToMessage;
  bool replyToSimplifyReferences;
  bool isChat = false;
  String chatGroupId;

  MessageBuilder() : super(MimeMessage()) {
    _message = _part as MimeMessage;
  }

  /// Adds a [recipient].
  /// Specify the [group] in case the recipient should not be added to the 'To' group.
  /// Compare [removeRecipient()] and [clearRecipients()].
  void addRecipient(MailAddress recipient,
      {RecipientGroup group = RecipientGroup.to}) {
    switch (group) {
      case RecipientGroup.to:
        to ??= <MailAddress>[];
        to.add(recipient);
        break;
      case RecipientGroup.cc:
        cc ??= <MailAddress>[];
        cc.add(recipient);
        break;
      case RecipientGroup.bcc:
        bcc ??= <MailAddress>[];
        bcc.add(recipient);
        break;
    }
  }

  /// Removes the specified [recipient] from To/Cc/Bcc fields.
  /// Compare [addRecipient()] and [clearRecipients()].
  void removeRecipient(MailAddress recipient) {
    if (to != null) {
      to.remove(recipient);
    }
    if (cc != null) {
      cc.remove(recipient);
    }
    if (bcc != null) {
      bcc.remove(recipient);
    }
  }

  /// Removes all recipients from this message.
  /// Compare [removeRecipient()] and [addRecipient()].
  void clearRecipients() {
    to = null;
    cc = null;
    bcc = null;
  }

  void _addMailAddressHeader(String name, List<MailAddress> addresses) {
    if (addresses != null) {
      addHeader(name, addresses.map((a) => a.encode()).join('; '));
    }
  }

  /// Creates the mime message based on the previous input.
  MimeMessage buildMimeMessage() {
    // check mandatory fields:
    if (from == null || from.isEmpty) {
      throw StateError('No From address specified');
    }
    // set default values for standard headers:
    date ??= DateTime.now();
    messageId ??= createMessageId(from.first.hostName,
        isChat: isChat, chatGroupId: chatGroupId);
    if (subject == null && replyToMessage != null) {
      var originalSubject = replyToMessage.decodeSubject();
      if (originalSubject != null) {
        subject = createReplySubject(originalSubject);
      }
    }

    _addMailAddressHeader('From', from);
    if (sender != null) {
      _addMailAddressHeader('Sender', [sender]);
    }
    _addMailAddressHeader('To', to);
    _addMailAddressHeader('Cc', cc);
    _addMailAddressHeader('Bcc', bcc);
    addHeader('Date', DateCodec.encodeDate(date));
    addHeader('Message-Id', messageId);
    if (subject != null) {
      addHeader('Subject', subject, encode: true);
    }
    addHeader(MailConventions.headerMimeVersion, '1.0');
    if (replyToMessage != null) {
      var originalMessageId = replyToMessage.getHeaderValue('message-id');
      addHeader(MailConventions.headerInReplyTo, originalMessageId);
      var originalReferences = replyToMessage.getHeaderValue('references');
      var references = originalReferences == null
          ? originalMessageId
          : replyToSimplifyReferences
              ? originalReferences
              : originalReferences + ' ' + originalMessageId;
      addHeader(MailConventions.headerReferences, references);
    }
    _buildPart();

    return _message;
  }

  /// Creates a text message.
  ///
  /// [from] the mandatory originator of the message
  /// [to] the mandatory list of recipients
  /// [text] the mandatory content of the message
  /// [cc] the optional "carbon copy" recipients that are informed about this message
  /// [bcc] the optional "blind carbon copy" recipients that should receive the message without others being able to see those recipients
  /// [subject] the optional subject of the message, if null and a [replyToMessage] is specified, then the subject of that message is being re-used.
  /// [date] the optional date of the message, is set to DateTime.now() by default
  /// [replyToMessage] is the message that this message is a reply to
  /// Set the optional [replyToSimplifyReferences] parameter to true in case only the root message-ID should be repeated instead of all references as calculated from the [replyToMessage],
  /// [messageId] the optional custom message ID
  /// Set the optional [isChat] to true in case a COI-compliant message ID should be generated, in case of a group message also specify the [chatGroupId].
  /// [chatGroupId] the optional ID of the chat group in case the message-ID should be generated.
  /// [characterSet] the optional character set, defaults to UTF8
  /// [encoding] the otional message encoding, defaults to 8bit
  static MimeMessage buildSimpleTextMessage(
      MailAddress from, List<MailAddress> to, String text,
      {List<MailAddress> cc,
      List<MailAddress> bcc,
      String subject,
      DateTime date,
      MimeMessage replyToMessage,
      bool replyToSimplifyReferences = false,
      String messageId,
      bool isChat = false,
      String chatGroupId,
      CharacterSet characterSet = CharacterSet.utf8,
      MessageEncoding encoding = MessageEncoding.eightBit}) {
    var builder = MessageBuilder()
      ..from = [from]
      ..to = to
      ..subject = subject
      ..text = text
      ..cc = cc
      ..bcc = bcc
      ..date = date
      ..replyToMessage = replyToMessage
      ..replyToSimplifyReferences = replyToSimplifyReferences
      ..messageId = messageId
      ..isChat = isChat
      ..chatGroupId = chatGroupId
      ..characterSet = characterSet
      ..encoding = encoding;

    return builder.buildMimeMessage();
  }

  /// Prepares to forward the given [originalMessage].
  /// Optionallyspecify the sending user with [from].
  /// You can also specify a custom [forwardHeaderTemplate]. The default replyHeaderTemplate contains the metadata information about the original message including subject, to, cc, date.
  /// Specify the [defaultForwardAbbreviation] if not 'Fwd' should be used at the beginning of the subject to indicate an reply.
  static MessageBuilder prepareForwardMessage(MimeMessage originalMessage,
      {MailAddress from,
      String forwardHeaderTemplate =
          MailConventions.defaultForwardHeaderTemplate,
      String defaultForwardAbbreviation =
          MailConventions.defaultForwardAbbreviation}) {
    String subject;
    var originalSubject = originalMessage.decodeSubject();
    if (originalSubject != null) {
      subject = createForwardSubject(originalSubject,
          defaultForwardAbbreviation: defaultForwardAbbreviation);
    } else {
      subject = defaultForwardAbbreviation;
    }
    var builder = MessageBuilder()
      ..subject = subject
      ..contentType = originalMessage.getHeaderContentType()
      ..contentTransferEncoding = originalMessage
          .getHeaderValue(MailConventions.headerContentTransferEncoding);
    if (from != null) {
      builder.from = [from];
    }
    var forwardHeader = fillTemplate(forwardHeaderTemplate, originalMessage);
    if (originalMessage.parts?.isNotEmpty ?? false) {
      var processedTextPlainPart = false;
      var processedTextHtmlPart = false;
      for (var part in originalMessage.parts) {
        builder.contentType = originalMessage.getHeaderContentType();
        if (part.isTextMediaType()) {
          if (!processedTextPlainPart &&
              part.mediaType.sub == MediaSubtype.textPlain) {
            var plainText = part.decodeContentText();
            var quotedPlainText = _quotePlain(forwardHeader, plainText);
            builder.addPlainText(quotedPlainText);
            processedTextPlainPart = true;
            continue;
          }
          if (!processedTextHtmlPart &&
              part.mediaType.sub == MediaSubtype.textHtml) {
            var decodedHtml = part.decodeContentText();
            var quotedHtml = '<br/><blockquote>' +
                forwardHeader.split('\r\n').join('<br/>\r\n') +
                '<br/>\r\n' +
                decodedHtml +
                '</blockquote>';
            builder.addHtmlText(quotedHtml);
            processedTextHtmlPart = true;
            continue;
          }
        }
        builder.addPart(mimePart: part);
      }
    } else {
      // no parts, this is most likely a plain text message:
      if (originalMessage.isPlainTextMessage()) {
        var plainText = originalMessage.decodeContentText();
        var quotedPlainText = _quotePlain(forwardHeader, plainText);
        builder.text = quotedPlainText;
      } else {
        //TODO check if this actually includes the data eg when forwarding a binary message
        builder.text = originalMessage.text;
      }
    }
    return builder;
  }

  static String _quotePlain(String header, String text) {
    return '>' +
        header.split('\r\n').join('\r\n>') +
        '\r\n>' +
        text.split('\r\n').join('\r\n>');
  }

  /// Prepares to create a reply to the given [originalMessage] to be send by the user specifed in [from].
  /// Set [quoteOriginalText] to true in case the original plain and html texts should be added to the generated message.
  /// You can also specify a custom [replyHeaderTemplate], which is only used when [quoteOriginalText] has been set to true. The default replyHeaderTemplate is 'On <date> <from> wrote:'.
  /// Set [replyToSimplifyReferences] to true if the References field should not contain the references of all messages in this thread.
  /// Specify the [defaultReplyAbbreviation] if not 'Re' should be used at the beginning of the subject to indicate an reply.
  static MessageBuilder prepareReplyToMessage(
      MimeMessage originalMessage, MailAddress from,
      {bool quoteOriginalText = false,
      String replyHeaderTemplate = MailConventions.defaultReplyHeaderTemplate,
      String defaultReplyAbbreviation =
          MailConventions.defaultReplyAbbreviation,
      bool replyToSimplifyReferences = false}) {
    String subject;
    var originalSubject = originalMessage.decodeSubject();
    if (originalSubject != null) {
      subject = createReplySubject(originalSubject,
          defaultReplyAbbreviation: defaultReplyAbbreviation);
    }
    var to = originalMessage.to;
    var cc = originalMessage.cc;
    if (from.email != null) {
      var replierEmailAddress = from.email.toLowerCase();
      if (to?.isNotEmpty ?? false) {
        to.removeWhere((a) => a?.email?.toLowerCase() == replierEmailAddress);
      }
      if (cc?.isNotEmpty ?? false) {
        cc.removeWhere((a) => a?.email?.toLowerCase() == replierEmailAddress);
      }
    }
    var replyTo = originalMessage.decodeHeaderMailAddressValue('reply-to');
    if (replyTo?.isEmpty ?? true) {
      replyTo = originalMessage.decodeHeaderMailAddressValue('sender');
    }
    if (replyTo?.isEmpty ?? true) {
      replyTo = originalMessage.decodeHeaderMailAddressValue('from');
    }
    to.addAll(replyTo);
    var builder = MessageBuilder()
      ..subject = subject
      ..replyToMessage = originalMessage
      ..from = [from]
      ..to = to
      ..cc = cc
      ..replyToSimplifyReferences = replyToSimplifyReferences;

    if (quoteOriginalText) {
      var replyHeader = fillTemplate(replyHeaderTemplate, originalMessage);

      var plainText = originalMessage.decodePlainTextPart();
      var quotedPlainText = _quotePlain(replyHeader, plainText);
      var decodedHtml = originalMessage.decodeHtmlTextPart();
      if (decodedHtml == null) {
        builder.text = quotedPlainText;
      } else {
        builder.setContentType(
            MediaType.fromSubtype(MediaSubtype.multipartAlternative));
        builder.addPlainText(quotedPlainText);
        var quotedHtml = '<blockquote><br/>' +
            replyHeader +
            '<br/>' +
            decodedHtml +
            '</blockquote>';
        builder.addHtmlText(quotedHtml);
      }
    }
    return builder;
  }

  /// Convenience method for initiating a multipart/alternative message
  /// In case you want to use 7bit instead of the default 8bit content transfer encoding, specify the optional [encoding].
  ///
  /// You can also create a new MessageBuilder and call [setContentType()] with the same effect when using the multipart/alternative media subtype.
  static MessageBuilder prepareMultipartAlternativeMessage(
      {MessageEncoding encoding = MessageEncoding.eightBit}) {
    return prepareMessageWithMediaType(MediaSubtype.multipartAlternative,
        encoding: encoding);
  }

  /// Convenience method for initiating a multipart/mixed message
  /// In case you want to use 7bit instead of the default 8bit content transfer encoding, specify the optional [encoding].
  ///
  /// You can also create a new MessageBuilder and call [setContentType()] with the same effect when using the multipart/mixed media subtype.
  static MessageBuilder prepareMultipartMixedMessage(
      {MessageEncoding encoding = MessageEncoding.eightBit}) {
    return prepareMessageWithMediaType(MediaSubtype.multipartMixed,
        encoding: encoding);
  }

  /// Convenience method for initiating a message with the specified media [subtype]
  /// In case you want to use 7bit instead of the default 8bit content transfer encoding, specify the optional [encoding].
  ///
  /// You can also create a new MessageBuilder and call [setContentType()] with the same effect when using the identical media subtype.
  static MessageBuilder prepareMessageWithMediaType(MediaSubtype subtype,
      {MessageEncoding encoding = MessageEncoding.eightBit}) {
    var mediaType = MediaType.fromSubtype(subtype);
    var builder = MessageBuilder()
      ..setContentType(mediaType)
      ..contentTransferEncoding = getContentTransferEncodingName(encoding);
    return builder;
  }

  /// Generates a message ID
  /// [hostName] the domain like 'example.com'
  /// Set the optional [isChat] to true in case a COI-compliant message ID should be generated, in case of a group message also specify the [chatGroupId].
  /// [chatGroupId] the optional ID of the chat group in case the message-ID should be generated.
  static String createMessageId(String hostName,
      {bool isChat = false, String chatGroupId}) {
    String id;
    var random = createRandomId();
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

  /// Encodes the specified [text] with given [encoding].
  /// Specify the [characterSet] when a different character set than utf8 should be used.
  static String encodeText(String text, MessageEncoding encoding,
      [CharacterSet characterSet = CharacterSet.utf8]) {
    switch (encoding) {
      case MessageEncoding.quotedPrintable:
        return MailCodec.quotedPrintable
            .encodeText(text, codec: getCodec(characterSet));
      case MessageEncoding.base64:
        return MailCodec.base64.encodeText(text, codec: getCodec(characterSet));
      default:
        return MailCodec.wrapText(text, wrapAtWordBoundary: true);
    }
  }

  /// Rerieves the codec for the specified [characterSet].
  static Codec getCodec(CharacterSet characterSet) {
    switch (characterSet) {
      case CharacterSet.ascii:
        return ascii;
      case CharacterSet.utf8:
        return utf8;
      case CharacterSet.latin1:
        return latin1;
    }
    return utf8;
  }

  /// Encodes the specified header [value].
  /// Specify the [encoding] when not the default quoted-printable encoding should be used.
  static String encodeHeaderValue(String value,
      [MessageEncoding encoding = MessageEncoding.quotedPrintable]) {
    switch (encoding) {
      case MessageEncoding.quotedPrintable:
        return MailCodec.quotedPrintable.encodeHeader(value);
      case MessageEncoding.base64:
        return MailCodec.base64.encodeHeader(value);
      default:
        return value;
    }
  }

  /// Retrieves the name of the specified [characterSet].
  static String getCharacterSetName(CharacterSet characterSet) {
    switch (characterSet) {
      case CharacterSet.utf8:
        return 'utf8';
      case CharacterSet.ascii:
        return 'ascii';
      case CharacterSet.latin1:
        return 'latin1';
    }
    return 'utf8';
  }

  /// Retrieves the name of the specified [encoding].
  static String getContentTransferEncodingName(MessageEncoding encoding) {
    switch (encoding) {
      case MessageEncoding.sevenBit:
        return '7bit';
      case MessageEncoding.eightBit:
        return '8bit';
      case MessageEncoding.quotedPrintable:
        return 'quoted-printable';
      case MessageEncoding.base64:
        return 'base64';
    }
    return '8bit';
  }

  /// Creates a subject based on the [originalSubject] taking mail conventions into account.
  /// Optionally specify the reply-indicator abbreviation by specifying [defaultReplyAbbreviation], which defaults to 'Re'.
  static String createReplySubject(String originalSubject,
      {String defaultReplyAbbreviation =
          MailConventions.defaultReplyAbbreviation}) {
    return _createSubject(originalSubject, defaultReplyAbbreviation,
        MailConventions.subjectReplyAbbreviations);
  }

  /// Creates a subject based on the [originalSubject] taking mail conventions into account.
  /// Optionally specify the forward-indicator abbreviation by specifying [defaultForwardAbbreviation], which defaults to 'Fwd'.
  static String createForwardSubject(String originalSubject,
      {String defaultForwardAbbreviation =
          MailConventions.defaultForwardAbbreviation}) {
    return _createSubject(originalSubject, defaultForwardAbbreviation,
        MailConventions.subjectForwardAbbreviations);
  }

  /// Creates a subject based on the [originalSubject] taking mail conventions into account.
  /// Optionally specify the reply-indicator abbreviation by specifying [defaultAbbreviation], which defaults to 'Re'.
  static String _createSubject(String originalSubject,
      String defaultAbbreviation, List<String> commonAbbreviations) {
    if (originalSubject == null) {
      return null;
    }
    var colonIndex = originalSubject.indexOf(':');
    if (colonIndex != -1) {
      var start = originalSubject.substring(0, colonIndex);
      if (commonAbbreviations.contains(start)) {
        // the original subject already contains a common reply abbreviation, e.g. 'Re: bla'
        return originalSubject;
      }
      // some mail servers use rewrite rules to adapt the subject, e.g start each external messages with '[EXT]'
      var prefixStartIndex = originalSubject.indexOf('[');
      if (prefixStartIndex == 0) {
        var prefixEndIndex = originalSubject.indexOf(']');
        if (prefixEndIndex < colonIndex) {
          start = start.substring(prefixEndIndex + 1).trim();
          if (commonAbbreviations.contains(start)) {
            // the original subject already contains a common reply abbreviation, e.g. 'Re: bla'
            return originalSubject.substring(prefixEndIndex + 1).trim();
          }
        }
      }
    }
    return '$defaultAbbreviation: $originalSubject';
  }

  /// Creates a new randomized ID text.
  /// Specify [length] when a different length than 14 characters should be used.
  ///
  /// This can be used as a multipart boundary or a message-ID, for example.
  static String createRandomId({int length = 14}) {
    var characters =
        '0123456789_abcdefghijklmnopqrstuvwxyz-ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    var characterRunes = characters.runes;
    var max = characters.length;
    var random = math.Random();
    var buffer = StringBuffer();
    for (var count = length; count > 0; count--) {
      var charIndex = random.nextInt(max);
      var rune = characterRunes.elementAt(charIndex);
      buffer.writeCharCode(rune);
    }
    return buffer.toString();
  }

  /// Fills the given [template] with values extracted from the provided [message].
  /// Currently the following templates are supported:
  ///  <from>: specifies the message sender (name plus email)
  ///  <date>: specifies the message date
  /// Note that for date formatting Dart's intl library is used: https://pub.dev/packages/intl
  /// You might want to specify the default locale by setting [Intl.defaultLocale] first.
  static String fillTemplate(String template, MimeMessage message) {
    var definedVariables = <String>[];
    var from = message.decodeHeaderMailAddressValue('sender');
    if (from?.isEmpty ?? true) {
      from = message.decodeHeaderMailAddressValue('from');
    }
    if (from?.isNotEmpty ?? false) {
      definedVariables.add('from');
      template = template.replaceAll('<from>', from.first.toString());
    }
    var date = message.decodeHeaderDateValue('date');
    if (date != null) {
      definedVariables.add('date');
      var dateStr = DateFormat.yMd().add_jm().format(date);
      template = template.replaceAll('<date>', dateStr);
    }
    var to = message.to;
    if (to?.isNotEmpty ?? false) {
      definedVariables.add('to');
      template = template.replaceAll('<to>', _renderAddresses(to));
    }
    var cc = message.cc;
    if (cc?.isNotEmpty ?? false) {
      definedVariables.add('cc');
      template = template.replaceAll('<cc>', _renderAddresses(cc));
    }
    var subject = message.decodeSubject();
    if (subject != null) {
      definedVariables.add('subject');
      template = template.replaceAll('<subject>', subject);
    }
    // remove any undefined variables from template:
    var optionalInclusionsExpression = RegExp(r'\[\[\w+\s[\s\S]+?\]\]');
    RegExpMatch match;
    while (
        (match = optionalInclusionsExpression.firstMatch(template)) != null) {
      var sequence = match.group(0);
      //print('sequence=$sequence');
      var separatorIndex = sequence.indexOf(' ', 2);
      var name = sequence.substring(2, separatorIndex);
      var replacement = '';
      if (definedVariables.contains(name)) {
        replacement =
            sequence.substring(separatorIndex + 1, sequence.length - 2);
      }
      template = template.replaceAll(sequence, replacement);
    }
    return template;
  }

  static String _renderAddresses(List<MailAddress> addresses) {
    var buffer = StringBuffer();
    var addDelimiter = false;
    for (var address in addresses) {
      if (addDelimiter) {
        buffer.write('; ');
      }
      address.write(buffer);
      addDelimiter = true;
    }
    return buffer.toString();
  }
}
