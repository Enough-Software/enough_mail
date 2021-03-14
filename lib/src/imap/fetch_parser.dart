import 'package:enough_mail/codecs/date_codec.dart';
import 'package:enough_mail/codecs/mail_codec.dart';
import 'package:enough_mail/imap/message_sequence.dart';
import 'package:enough_mail/mail_address.dart';
import 'package:enough_mail/media_type.dart';
import 'package:enough_mail/mime_message.dart';
import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/imap/response_parser.dart';
import 'package:enough_mail/imap/response.dart';
import 'package:enough_mail/mime_data.dart';

import 'imap_response.dart';

class FetchParser extends ResponseParser<FetchImapResult> {
  final List<MimeMessage> _messages = <MimeMessage>[];

  /// The most recent message that has beeen parsed
  MimeMessage? lastParsedMessage;

  /// The most recent VANISHED response
  MessageSequence? vanishedMessages;

  MessageSequence? modifiedSequence;

  final bool isUidFetch;
  FetchParser(this.isUidFetch);

  @override
  FetchImapResult? parse(
      ImapResponse details, Response<FetchImapResult> response) {
    final text = details.parseText!;
    final modifiedIndex = text.indexOf('[MODIFIED ');
    if (modifiedIndex != -1) {
      final modifiedEntries = ParserHelper.parseListIntEntries(
          text, modifiedIndex + '[MODIFIED '.length, ']', ',');
      if (modifiedEntries != null) {
        modifiedSequence =
            MessageSequence.fromIds(modifiedEntries, isUid: isUidFetch);
      }
    }
    if (response.isOkStatus ||
        _messages.isNotEmpty ||
        (vanishedMessages != null && vanishedMessages!.isNotEmpty())) {
      return FetchImapResult(_messages, vanishedMessages,
          modifiedSequence: modifiedSequence);
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<FetchImapResult>? response) {
    var details = imapResponse.first.line!;
    var fetchIndex = details.indexOf(' FETCH ');
    lastParsedMessage = null;
    if (fetchIndex != -1) {
      // eg "* 2389 FETCH (...)"
      final sequenceId = parseInt(details, 2, ' ');
      MimeMessage message;
      if (_messages.isNotEmpty && _messages.last.sequenceId == sequenceId) {
        message = _messages.last;
      } else {
        message = MimeMessage()..sequenceId = sequenceId;
        _messages.add(message);
      }
      lastParsedMessage = message;
      var iterator = imapResponse.iterate();
      for (var value in iterator.values!) {
        if (value.value == 'FETCH') {
          _parseFetch(message, value, imapResponse);
        }
      }

      return true;
    } else if (details.startsWith('* VANISHED (EARLIER) ')) {
      var details = imapResponse.parseText!;

      var messageSequenceText = details.startsWith('*')
          ? details.substring('* VANISHED (EARLIER) '.length)
          : details.substring('VANISHED (EARLIER) '.length);
      vanishedMessages =
          MessageSequence.parse(messageSequenceText, isUidSequence: true);
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }

  void _parseFetch(
      MimeMessage message, ImapValue fetchValue, ImapResponse imapResponse) {
    var children = fetchValue.children!;
    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      var hasNext = i < children.length - 1;
      switch (child.value) {
        case 'UID':
          if (hasNext) {
            message.uid = int.parse(children[i + 1].value!);
            i++;
          }
          break;
        case 'MODSEQ':
          if (hasNext && (children[i + 1].children?.length == 1)) {
            message.modSequence =
                int.tryParse(children[i + 1].children![0].value!);
            i++;
          }
          break;
        case 'FLAGS':
          message.flags =
              List.from(child.children!.map<String?>((flag) => flag.value));
          break;
        case 'INTERNALDATE':
          if (hasNext) {
            message.internalDate = children[i + 1].value;
            i++;
          }
          break;
        case 'RFC822.SIZE':
          if (hasNext) {
            message.size = int.parse(children[i + 1].value!);
            i++;
          }
          break;
        case 'ENVELOPE':
          _parseEnvelope(message, child);
          break;
        case 'BODY':
          _parseBody(message, child);
          break;
        case 'BODYSTRUCTURE':
          _parseBodyStructure(message, child);
          break;
        case 'BODY[HEADER]':
        case 'RFC822.HEADER':
          if (hasNext) {
            i++;
            _parseBodyHeader(message, children[i]);
          }
          break;
        case 'BODY[TEXT]':
        case 'RFC822.TEXT':
          if (hasNext) {
            i++;
            _parseBodyText(message, children[i]);
          }
          break;
        case 'BODY[]':
        case 'RFC822':
          if (hasNext) {
            i++;
            _parseBodyFull(message, children[i]);
          }
          break;
        default:
          if (hasNext &&
              child.value!.startsWith('BODY[') &&
              child.value!.endsWith(']')) {
            i++;
            _parseBodyPart(message, child.value!, children[i]);
          } else {
            print(
                'fetch: encountered unexpected/unsupported element ${child.value} at $i in ${imapResponse.parseText}');
          }
      }
    }
  }

  /// parses elements starting with `BODY[`, excluding `BODY[]` and `BODY[HEADER]` which are handled separately
  /// e.g. `BODY[0]` or `BODY[HEADER.FIELDS (REFERENCES)]`
  void _parseBodyPart(
      MimeMessage message, String bodyPartDefinition, ImapValue imapValue) {
    // this matches
    // BODY[HEADER.FIELDS (name1,name2)], as well as
    // BODY[HEADER.FIELDS.NOT (name1,name2)]
    if (bodyPartDefinition.startsWith('BODY[HEADER.FIELDS')) {
      _parseBodyHeader(message, imapValue);
    } else {
      final startIndex = 'BODY['.length;
      final endIndex = bodyPartDefinition.length - 1;
      final fetchId = bodyPartDefinition.substring(startIndex, endIndex);
      final part = MimePart();
      if (imapValue.value != null) {
        part.mimeData = TextMimeData(imapValue.value!, false);
      } else if (imapValue.data != null) {
        part.mimeData = BinaryMimeData(imapValue.data!, false);
      }
      part.parse();
      //print('$fetchId: results in [${imapValue.value}]');
      message.setPart(fetchId, part);
    }
  }

  void _parseBodyFull(MimeMessage message, ImapValue bodyValue) {
    //print("Parsing BODY[]\n[${bodyValue.value}]");
    if (bodyValue.data != null) {
      message.mimeData = BinaryMimeData(bodyValue.data!, true);
    } else {
      message.mimeData = TextMimeData(bodyValue.value!, true);
      //print("Parsing BODY text \n$bodyText");
    }
    // ensure all headers are set:
    message.parse();
  }

  HeaderParseResult _parseBodyHeader(
      MimeMessage message, ImapValue headerValue) {
    //print('Parsing BODY[HEADER]\n[${headerValue.value}]');
    final headerParseResult =
        ParserHelper.parseHeader(headerValue.valueOrDataText!);
    message.headers = headerParseResult.headersList;
    return headerParseResult;
  }

  void _parseBodyText(MimeMessage message, ImapValue textValue) {
    //print('Parsing BODY[TEXT]\n[${textValue.value}]');
    message.mimeData = textValue.data != null
        ? BinaryMimeData(textValue.data!, false)
        : TextMimeData(textValue.value!, false);
  }

  /// Also compare:
  /// * http://sgerwk.altervista.org/imapbodystructure.html
  /// * https://tools.ietf.org/html/rfc3501#section-7.4.2
  /// * http://hea-www.cfa.harvard.edu/~fine/opinions/IMAPsucks.html
  void _parseBodyRecursive(BodyPart body, ImapValue bodyValue) {
    var isMultipartSubtypeSet = false;
    var multipartChildIndex = -1;
    var children = bodyValue.children!;
    if (children.length >= 7 && children[0].children == null) {
      // this is a direct type:
      var parsed = _parseBodyStructureFrom(children);
      body.bodyRaw = parsed.bodyRaw;
      body.contentDisposition = parsed.contentDisposition;
      body.contentType = parsed.contentType;
      body.description = parsed.description;
      body.encoding = parsed.encoding;
      body.envelope = parsed.envelope;
      body.cid = parsed.cid;
      body.numberOfLines = parsed.numberOfLines;
      body.size = parsed.size;
      return;
    }
    for (var childIndex = 0; childIndex < children.length; childIndex++) {
      var child = children[childIndex];
      if (child.value == null &&
          child.children != null &&
          child.children!.isNotEmpty &&
          child.children!.first.value == null) {
        // this is a nested structure
        var part = BodyPart();
        body.addPart(part);
        _parseBodyRecursive(part, child);
      } else if (!isMultipartSubtypeSet &&
          child.children != null &&
          child.children!.length >= 7) {
        // TODO just counting cannot be a big enough indicator, compare for example ""mixed" ("charset" "utf8" "boundary" "cTOLC7EsqRfMsG")"
        // this is a structure value
        var structs = child.children!;
        var part = _parseBodyStructureFrom(structs);
        body.addPart(part);
      } else if (!isMultipartSubtypeSet) {
        // this is the type:
        isMultipartSubtypeSet = true;
        multipartChildIndex = childIndex;
        body.contentType =
            ContentTypeHeader('multipart/${child.value?.toLowerCase()}');
      } else if (childIndex == multipartChildIndex + 1 &&
          child.children != null &&
          child.children!.length > 1) {
        var parameters = child.children!;
        for (var i = 0; i < parameters.length; i += 2) {
          body.contentType!
              .setParameter(parameters[i].value!, parameters[i + 1].value);
        }
      }
    }
  }

  BodyPart _parseBodyStructureFrom(List<ImapValue> structs) {
    var size = int.tryParse(structs[6].value!);
    var mediaType =
        MediaType.fromText('${structs[0].value}/${structs[1].value}');
    var part = BodyPart()
      ..cid = _checkForNil(structs[3].value)
      ..description = _checkForNil(structs[4].value)
      ..encoding = _checkForNil(structs[5].value)?.toLowerCase()
      ..size = size
      ..contentType = ContentTypeHeader.from(mediaType);
    var contentTypeParameters = structs[2].children;
    if (contentTypeParameters != null && contentTypeParameters.length > 1) {
      for (var i = 0; i < contentTypeParameters.length; i += 2) {
        var name = contentTypeParameters[i].value!;
        var value = contentTypeParameters[i + 1].value;
        part.contentType!.setParameter(name, value);
      }
    }
    var startIndex = 7;
    if (mediaType.isText && structs.length > 7 && structs[7].value != null) {
      part.numberOfLines = int.tryParse(structs[7].value!);
      startIndex = 8;
    } else if (mediaType.isMessage &&
        mediaType.sub == MediaSubtype.messageRfc822) {
      // [7]
      // A body type of type MESSAGE and subtype RFC822 contains,
      // immediately after the basic fields, the envelope structure,
      // body structure, and size in text lines of the encapsulated
      // message.
      if (structs.length > 9) {
        part.envelope = _parseEnvelope(null, structs[7]);
        var child = BodyPart();
        part.addPart(child);
        _parseBodyRecursive(child, structs[8]);
        part.numberOfLines = int.tryParse(structs[9].value!);
      }
      startIndex += 3;
    }
    if ((structs.length > startIndex + 1) &&
        (structs[startIndex + 1].children?.isNotEmpty ?? false)) {
      // read content disposition
      // example: <null>[attachment, <null>[filename, testimage.jpg, modification-date, Fri, 27 Jan 2017 16:34:4 +0100, size, 13390]]
      var parts = structs[startIndex + 1].children!;
      if (parts[0].value != null) {
        var contentDisposition =
            ContentDispositionHeader(parts[0].value!.toLowerCase());
        var parameters = parts[1].children;
        if (parameters != null && parameters.length > 1) {
          for (var i = 0; i < parameters.length; i += 2) {
            contentDisposition.setParameter(
                parameters[i].value!, parameters[i + 1].value);
          }
        }
        part.contentDisposition = contentDisposition;
      } else {
        print('Unable to parse content disposition from:');
        print(parts);
      }
    }
    return part;
  }

  void _parseBody(MimeMessage message, ImapValue bodyValue) {
    // A parenthesized list that describes the [MIME-IMB] body
    // structure of a message.  This is computed by the server by
    // parsing the [MIME-IMB] header fields, defaulting various fields
    // as necessary.

    // For example, a simple text message of 48 lines and 2279 octets
    // can have a body structure of: ("TEXT" "PLAIN" ("CHARSET"
    // "US-ASCII") NIL NIL "7BIT" 2279 48)

    // Multiple parts are indicated by parenthesis nesting.  Instead
    // of a body type as the first element of the parenthesized list,
    // there is a sequence of one or more nested body structures.  The
    // second element of the parenthesized list is the multipart
    // subtype (mixed, digest, parallel, alternative, etc.).

    // For example, a two part message consisting of a text and a
    // BASE64-encoded text attachment can have a body structure of:
    // (("TEXT" "PLAIN" ("CHARSET" "US-ASCII") NIL NIL "7BIT" 1152
    // 23)("TEXT" "PLAIN" ("CHARSET" "US-ASCII" "NAME" "cc.diff")
    // "<960723163407.20117h@cac.washington.edu>" "Compiler diff"
    // "BASE64" 4554 73) "MIXED")

    // [0]body type
    //   A string giving the content media type name as defined in
    //   [MIME-IMB].

    // [1]body subtype
    //   A string giving the content subtype name as defined in
    //   [MIME-IMB].

    // [2] body parameter parenthesized list
    //   A parenthesized list of attribute/value pairs [e.g., ("foo"
    //   "bar" "baz" "rag") where "bar" is the value of "foo" and
    //   "rag" is the value of "baz"] as defined in [MIME-IMB].

    // [3]body id
    //   A string giving the content id as defined in [MIME-IMB].

    // [4]body description
    //   A string giving the content description as defined in
    //   [MIME-IMB].

    // [5]body encoding
    //   A string giving the content transfer encoding as defined in
    //   [MIME-IMB].

    // [6]body size
    //   A number giving the size of the body in octets.  Note that
    //   this size is the size in its transfer encoding and not the
    //   resulting size after any decoding.

    // [7]
    // A body type of type MESSAGE and subtype RFC822 contains,
    // immediately after the basic fields, the envelope structure,
    // body structure, and size in text lines of the encapsulated
    // message.

    // A body type of type TEXT contains, immediately after the basic
    // fields, the size of the body in text lines.  Note that this
    // size is the size in its content transfer encoding and not the
    // resulting size after any decoding.

    // Extension data follows the multipart subtype.  Extension data
    //  is never returned with the BODY fetch, but can be returned with
    //  a BODYSTRUCTURE fetch.  Extension data, if present, MUST be in
    //  the defined order.  The extension data of a multipart body part
    //  are in the following order:

    //  [7 / 8]
    // body parameter parenthesized list
    //     A parenthesized list of attribute/value pairs [e.g., ("foo"
    //     "bar" "baz" "rag") where "bar" is the value of "foo", and
    //     "rag" is the value of "baz"] as defined in [MIME-IMB].

    //  [8 / 9]
    //  body disposition
    //     A parenthesized list, consisting of a disposition type
    //     string, followed by a parenthesized list of disposition
    //     attribute/value pairs as defined in [DISPOSITION].

    //  [9 / 10]
    //  body language
    //     A string or parenthesized list giving the body language
    //     value as defined in [LANGUAGE-TAGS].

    //  [10 / 11]
    //  body location
    //     A string list giving the body content URI as defined in
    //     [LOCATION].
    //
    //
    // The extension data of a non-multipart body part are in the
    //  following order:

    //  [7 / 8]
    //  body MD5
    //     A string giving the body MD5 value as defined in [MD5].
    //
    //  [8 / 9]
    // body disposition
    //     A parenthesized list with the same content and function as
    //     the body disposition for a multipart body part.

    //  [9 / 10]
    //  body language
    //     A string or parenthesized list giving the body language
    //     value as defined in [LANGUAGE-TAGS].

    //  [10 / 11]
    //  body location
    //     A string list giving the body content URI as defined in
    //     [LOCATION].
    //print('body: $bodyValue');
    var body = BodyPart();
    _parseBodyRecursive(body, bodyValue);
    message.body = body;
  }

  void _parseBodyStructure(MimeMessage message, ImapValue bodyValue) {
    //print('bodystructure: $bodyValue');
    _parseBody(message, bodyValue);
  }

  /// parses the envelope structure of a message
  Envelope? _parseEnvelope(MimeMessage? message, ImapValue envelopeValue) {
    // The fields of the envelope structure are in the following
    // order: [0] date, [1]subject, [2]from, [3]sender, [4]reply-to, [5]to, [6]cc, [7]bcc,
    // [8]in-reply-to, and [9]message-id.  The date, subject, in-reply-to,
    // and message-id fields are strings.  The from, sender, reply-to,
    // to, cc, and bcc fields are parenthesized lists of address
    // structures.

    // If the Date, Subject, In-Reply-To, and Message-ID header lines
    // are absent in the [RFC-2822] header, the corresponding member
    // of the envelope is NIL; if these header lines are present but
    // empty the corresponding member of the envelope is the empty
    // string.
    Envelope? envelope;
    var children = envelopeValue.children;
    //print("envelope: $children");
    if (children != null && children.length >= 10) {
      var rawDate = _checkForNil(children[0].value);
      var rawSubject = _checkForNil(children[1].valueOrDataText);
      envelope = Envelope()
        ..date = rawDate != null ? DateCodec.decodeDate(rawDate) : null
        ..subject =
            rawSubject != null ? MailCodec.decodeHeader(rawSubject) : null
        ..from = _parseAddressList(children[2])
        ..sender = _parseAddressListFirst(children[3])
        ..replyTo = _parseAddressList(children[4])
        ..to = _parseAddressList(children[5])
        ..cc = _parseAddressList(children[6])
        ..bcc = _parseAddressList(children[7])
        ..inReplyTo = _checkForNil(children[8].value)
        ..messageId = _checkForNil(children[9].value);
      if (message != null) {
        message.envelope = envelope;
        if (rawDate != null) {
          message.addHeader('Date', rawDate);
        }
        if (rawSubject != null) {
          message.addHeader('Subject', rawSubject);
        }
        message.addHeader('In-Reply-To', envelope.inReplyTo);
        message.addHeader('Message-ID', envelope.messageId);
      }
    }
    return envelope;
  }

  MailAddress? _parseAddressListFirst(ImapValue addressValue) {
    var addresses = _parseAddressList(addressValue);
    if (addresses == null || addresses.isEmpty) {
      return null;
    }
    return addresses.first;
  }

  List<MailAddress>? _parseAddressList(ImapValue addressValue) {
    if (addressValue.value == 'NIL') {
      return null;
    }
    var addresses = <MailAddress>[];
    if (addressValue.children != null) {
      for (var child in addressValue.children!) {
        final address = _parseAddress(child);
        if (address != null) {
          addresses.add(address);
        }
      }
    }
    return addresses;
  }

  MailAddress? _parseAddress(ImapValue addressValue) {
    // An address structure is a parenthesized list that describes an
    // electronic mail address.  The fields of an address structure
    // are in the following order: personal name, [SMTP]
    // at-domain-list (source route), mailbox name, and host name.

    // [RFC-2822] group syntax is indicated by a special form of
    // address structure in which the host name field is NIL.  If the
    // mailbox name field is also NIL, this is an end of group marker
    // (semi-colon in RFC 822 syntax).  If the mailbox name field is
    // non-NIL, this is a start of group marker, and the mailbox name
    // field holds the group name phrase.

    if (addressValue.value == 'NIL' ||
        addressValue.children == null ||
        addressValue.children!.length < 4) {
      return null;
    }
    var children = addressValue.children!;
    return MailAddress.fromEnvelope(
        MailCodec.decodeHeader(_checkForNil(children[0].value)),
        _checkForNil(children[1].value),
        _checkForNil(children[2].value),
        _checkForNil(children[3].value));
  }

  String? _checkForNil(String? value) {
    if (value == 'NIL') {
      return null;
    }
    return value;
  }
}
