import '../../codecs/date_codec.dart';
import '../../codecs/mail_codec.dart';
import '../../imap/message_sequence.dart';
import '../../imap/response.dart';
import '../../mail_address.dart';
import '../../media_type.dart';
import '../../mime_data.dart';
import '../../mime_message.dart';
import 'imap_response.dart';
import 'parser_helper.dart';
import 'response_parser.dart';

/// Parses FETCH IMAP responses
class FetchParser extends ResponseParser<FetchImapResult> {
  /// Creates a new parser
  FetchParser({required this.isUidFetch});

  final List<MimeMessage> _messages = <MimeMessage>[];

  /// The most recent message that has been parsed
  MimeMessage? lastParsedMessage;

  /// The most recent VANISHED response
  MessageSequence? vanishedMessages;

  /// The modified sequence if defined in the FETCH response
  MessageSequence? modifiedSequence;

  /// Is the FETCH request based on UIDs instead of sequence-IDs?
  final bool isUidFetch;

  @override
  FetchImapResult? parse(
      ImapResponse imapResponse, Response<FetchImapResult> response) {
    final text = imapResponse.parseText;
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
        (vanishedMessages != null && vanishedMessages!.isNotEmpty)) {
      return FetchImapResult(_messages, vanishedMessages,
          modifiedSequence: modifiedSequence);
    }
    return null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<FetchImapResult>? response) {
    final firstLine = imapResponse.first.line;
    if (firstLine == null) {
      return false;
    }
    final fetchIndex = firstLine.indexOf(' FETCH ');
    lastParsedMessage = null;
    if (fetchIndex != -1) {
      // eg "* 2389 FETCH (...)"
      final sequenceId = parseInt(firstLine, 2, ' ');
      MimeMessage message;
      if (_messages.isNotEmpty && _messages.last.sequenceId == sequenceId) {
        message = _messages.last;
      } else {
        message = MimeMessage()..sequenceId = sequenceId;
        _messages.add(message);
      }
      lastParsedMessage = message;
      final iterator = imapResponse.iterate();
      for (final value in iterator.values) {
        if (value.value == 'FETCH') {
          _parseFetch(message, value, imapResponse);
        }
      }

      return true;
    } else if (firstLine.startsWith('* VANISHED (EARLIER) ')) {
      final parseText = imapResponse.parseText;

      final messageSequenceText = parseText.startsWith('*')
          ? parseText.substring('* VANISHED (EARLIER) '.length)
          : parseText.substring('VANISHED (EARLIER) '.length);
      vanishedMessages =
          MessageSequence.parse(messageSequenceText, isUidSequence: true);
      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }

  void _parseFetch(
      MimeMessage message, ImapValue fetchValue, ImapResponse imapResponse) {
    final children = fetchValue.children!;
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final hasNext = i < children.length - 1;
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

  /// Parse a body part
  ///
  /// parses elements starting with `BODY[`, excluding `BODY[]` and
  /// `BODY[HEADER]` which are handled separately
  /// e.g. `BODY[0]` or `BODY[HEADER.FIELDS (REFERENCES)]`
  void _parseBodyPart(
      MimeMessage message, String bodyPartDefinition, ImapValue imapValue) {
    // this matches
    // BODY[HEADER.FIELDS (name1,name2)], as well as
    // BODY[HEADER.FIELDS.NOT (name1,name2)]
    if (bodyPartDefinition.startsWith('BODY[HEADER.FIELDS')) {
      _parseBodyHeader(message, imapValue);
    } else {
      const startIndex = 'BODY['.length;
      final endIndex = bodyPartDefinition.length - 1;
      final fetchId = bodyPartDefinition.substring(startIndex, endIndex);
      final part = MimePart();
      if (imapValue.value != null) {
        part.mimeData = TextMimeData(imapValue.value!, containsHeader: false);
      } else if (imapValue.data != null) {
        part.mimeData = BinaryMimeData(imapValue.data!, containsHeader: false);
      }
      part.parse();
      //print('$fetchId: results in [${imapValue.value}]');
      message.setPart(fetchId.replaceFirst('.HEADER', ''), part);
    }
  }

  void _parseBodyFull(MimeMessage message, ImapValue bodyValue) {
    //print("Parsing BODY[]\n[${bodyValue.value}]");
    if (bodyValue.data != null) {
      message.mimeData = BinaryMimeData(bodyValue.data!, containsHeader: true);
    } else {
      message.mimeData = TextMimeData(bodyValue.value!, containsHeader: true);
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
        ? BinaryMimeData(textValue.data!, containsHeader: false)
        : TextMimeData(textValue.value!, containsHeader: false);
  }

  /// Also compare:
  /// * http://sgerwk.altervista.org/imapbodystructure.html
  /// * https://tools.ietf.org/html/rfc3501#section-7.4.2
  /// * http://hea-www.cfa.harvard.edu/~fine/opinions/IMAPsucks.html
  void _parseBodyRecursive(BodyPart body, ImapValue bodyValue) {
    // print('_parseBodyRecursive from $bodyValue');
    var isMultipartSubtypeSet = false;
    var multipartChildIndex = -1;
    final children = bodyValue.children!;
    if (children.length >= 7 && children[0].children == null) {
      // this is a direct type:
      final parsed = _parseBodyStructureFrom(children);
      body
        ..bodyRaw = parsed.bodyRaw
        ..contentDisposition = parsed.contentDisposition
        ..contentType = parsed.contentType
        ..description = parsed.description
        ..encoding = parsed.encoding
        ..envelope = parsed.envelope
        ..cid = parsed.cid
        ..numberOfLines = parsed.numberOfLines
        ..size = parsed.size;
      return;
    }
    for (var childIndex = 0; childIndex < children.length; childIndex++) {
      final child = children[childIndex];
      if (child.value == null &&
          child.children != null &&
          child.children!.isNotEmpty &&
          child.children!.first.value == null) {
        // this is a nested structure
        final part = BodyPart();
        body.addPart(part);
        _parseBodyRecursive(part, child);
      } else if (!isMultipartSubtypeSet &&
          child.children != null &&
          child.children!.length >= 7) {
        // TODO just counting cannot be a big enough indicator,
        // compare for example
        // ""mixed" ("charset" "utf8" "boundary" "cs2da2ss7EsqRfMsG")"
        // this is a structure value
        final structures = child.children!;
        final part = _parseBodyStructureFrom(structures);
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
        final parameters = child.children!;
        for (var i = 0; i < parameters.length; i += 2) {
          body.contentType!.setParameter(
              parameters[i].value!, parameters[i + 1].valueOrDataText!);
        }
      }
    }
  }

  BodyPart _parseBodyStructureFrom(List<ImapValue> structures) {
    final size = int.tryParse(structures[6].value!);
    final mediaType =
        MediaType.fromText('${structures[0].value}/${structures[1].value}');
    final part = BodyPart()
      ..cid = _checkForNil(structures[3].value)
      ..description = _checkForNil(structures[4].value)
      ..encoding = _checkForNil(structures[5].value)?.toLowerCase()
      ..size = size
      ..contentType = ContentTypeHeader.from(mediaType);
    final contentTypeParameters = structures[2].children;
    if (contentTypeParameters != null && contentTypeParameters.length > 1) {
      for (var i = 0; i < contentTypeParameters.length; i += 2) {
        final name = contentTypeParameters[i].value;
        final value = contentTypeParameters[i + 1].valueOrDataText;
        // print('content-type: $name=$value');
        if (name != null && value != null) {
          part.contentType!.setParameter(name, value);
        }
      }
    }
    var startIndex = 7;
    if (mediaType.isText &&
        structures.length > 7 &&
        structures[7].value != null) {
      part.numberOfLines = int.tryParse(structures[7].value!);
      startIndex = 8;
    } else if (mediaType.isMessage &&
        mediaType.sub == MediaSubtype.messageRfc822) {
      // [7]
      // A body type of type MESSAGE and subtype RFC822 contains,
      // immediately after the basic fields, the envelope structure,
      // body structure, and size in text lines of the encapsulated
      // message.
      if (structures.length > 9) {
        part.envelope = _parseEnvelope(null, structures[7]);
        final child = BodyPart();
        part.addPart(child);
        _parseBodyRecursive(child, structures[8]);
        part.numberOfLines = int.tryParse(structures[9].value!);
      }
      startIndex += 3;
    }
    if ((structures.length > startIndex + 1) &&
        (structures[startIndex + 1].children?.isNotEmpty ?? false)) {
      // read content disposition
      // example: <null>[attachment, <null>[filename, testImage.jpg,
      // modification-date, Fri, 27 Jan 2017 16:34:4 +0100, size, 13390]]
      final parts = structures[startIndex + 1].children!;
      if (parts[0].value != null) {
        final contentDisposition =
            ContentDispositionHeader(parts[0].value!.toLowerCase());
        final parameters = parts[1].children;
        if (parameters != null && parameters.length > 1) {
          for (var i = 0; i < parameters.length; i += 2) {
            final name = parameters[i].value;
            final value = parameters[i + 1].valueOrDataText;
            if (name != null && value != null) {
              // print('content-disposition: $name=$value');
              contentDisposition.setParameter(name, value);
            }
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
    final body = BodyPart();
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
    // order: [0] date, [1]subject, [2]from, [3]sender, [4]reply-to, [5]to,
    // [6]cc, [7]bcc, [8]in-reply-to, and [9]message-id.
    //
    // The date, subject, in-reply-to,
    // and message-id fields are strings.  The from, sender, reply-to,
    // to, cc, and bcc fields are parenthesized lists of address
    // structures.

    // If the Date, Subject, In-Reply-To, and Message-ID header lines
    // are absent in the [RFC-2822] header, the corresponding member
    // of the envelope is NIL; if these header lines are present but
    // empty the corresponding member of the envelope is the empty
    // string.
    Envelope? envelope;
    final children = envelopeValue.children;
    //print("envelope: $children");
    if (children != null && children.length >= 10) {
      final rawDate = _checkForNil(children[0].value);
      final rawSubject = _checkForNil(children[1].valueOrDataText);
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
        message
          ..addHeader('In-Reply-To', envelope.inReplyTo)
          ..addHeader('Message-ID', envelope.messageId);
      }
    }
    return envelope;
  }

  MailAddress? _parseAddressListFirst(ImapValue addressValue) {
    final addresses = _parseAddressList(addressValue);
    if (addresses == null || addresses.isEmpty) {
      return null;
    }
    return addresses.first;
  }

  List<MailAddress>? _parseAddressList(ImapValue addressValue) {
    if (addressValue.value == 'NIL') {
      return null;
    }
    final addresses = <MailAddress>[];
    if (addressValue.children != null) {
      for (final child in addressValue.children!) {
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
    final children = addressValue.children!;
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
