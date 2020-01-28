import 'package:enough_mail/src/imap/parser_helper.dart';
import 'package:enough_mail/src/imap/response_parser.dart';

import '../../enough_mail.dart';
import 'imap_response.dart';

class FetchParser extends ResponseParser<List<Message>> {
  final List<Message> _messages = <Message>[];

  @override
  List<Message> parse(ImapResponse details, Response<List<Message>> response) {
    return response.isOkStatus ? _messages : null;
  }

  @override
  bool parseUntagged(
      ImapResponse imapResponse, Response<List<Message>> response) {
    var details = imapResponse.first.line;
    var fetchIndex = details.indexOf(' FETCH ');
    var message = Message();
    // eg "* 2389 FETCH (...)"

    message.sequenceId = parseInt(details, 2, ' ');
    _messages.add(message);
    if (fetchIndex != -1) {
      var iterator = imapResponse.iterate();
      for (var value in iterator.values) {
        if (value.value == 'FETCH') {
          _parseFetch(message, value);
        }
      }

      return true;
    }
    return super.parseUntagged(imapResponse, response);
  }

  void _parseFetch(Message message, ImapValue fetchValue) {
    var children = fetchValue.children;
    for (var i = 0; i < children.length; i++) {
      var child = children[i];
      var hasNext = i < children.length - 1;
      switch (child.value) {
        case 'FLAGS':
          message.flags =
              List.from(child.children.map<String>((flag) => flag.value));
          break;
        case 'INTERNALDATE':
          if (hasNext) {
            message.internalDate = children[i + 1].value;
            i++;
          }
          break;
        case 'RFC822.SIZE':
          if (hasNext) {
            message.size = int.parse(children[i + 1].value);
            i++;
          }
          break;
        case 'ENVELOPE':
          _parseEnvelope(message, child);
          break;
        case 'BODY':
          _parseBody(message, child);
          break;
        case 'BODY[HEADER]':
          if (hasNext) {
            i++;
            _parseBodyHeader(message, children[i]);
          }
          break;
        case 'BODY[]':
          if (hasNext) {
            i++;
            _parseBodyFull(message, children[i]);
          }
          break;
        default:
          if (hasNext &&
              child.value.startsWith('BODY[') &&
              child.value.endsWith(']')) {
            i++;
            _parseBodyPart(message, child.value, children[i]);
          } else {
            print(
                'fetch: encountered unexpected/unsupported element ${child.value}');
          }
      }
    }
  }

  /// parses elements starting with 'BODY[', excluding 'BODY[]' and 'BODY[HEADER]' which are handled separately
  /// e.g. 'BODY[0]' or 'BODY[HEADER.FIELDS (REFERENCES)]'
  void _parseBodyPart(
      Message message, String bodyPartDefinition, ImapValue imapValue) {
    // this matches 
    // BODY[HEADER.FIELDS (name1,name2)], as well as
    // BODY[HEADER.FIELDS.NOT (name1,name2)]
    if (bodyPartDefinition.startsWith('BODY[HEADER.FIELDS')) {
      _parseBodyHeader(message, imapValue);
    } else {
    var startIndex = 'BODY['.length;
    var endIndex = bodyPartDefinition.length - 1;
    var partIndex =
        int.tryParse(bodyPartDefinition.substring(startIndex, endIndex));
    //print("parse body part: $partIndex\n${headerValue.value}\n");
    if(partIndex == null) {
      print('Error: unsupported structure in FETCH response: $bodyPartDefinition');
    } else {
    message.setBodyPart(partIndex, imapValue.value);
    }
    }
  }

  void _parseBodyFull(Message message, ImapValue headerValue) {
    //print("Parsing BODY[]\n[${headerValue.value}]");
    var headerParseResult = _parseBodyHeader(message, headerValue);
    if (headerParseResult.bodyStartIndex != null) {
      if (headerParseResult.bodyStartIndex >= headerValue.value.length) {
        print(
            'error: got invalid body start index ${headerParseResult.bodyStartIndex} with max index being ${(headerValue.value.length - 1)}');
        var i = 1;
        for (var header in message.headers) {
          print('-- $i: $header');
          i++;
        }
        return;
      }
      var bodyText =
          headerValue.value.substring(headerParseResult.bodyStartIndex);
      message.bodyRaw = bodyText;
      //print("Parsing BODY text \n$bodyText");
    }
  }

  HeaderParseResult _parseBodyHeader(Message message, ImapValue headerValue) {
    //print('Parsing BODY[HEADER]\n[${headerValue.value}]');
    var headerParseResult = ParserHelper.parseHeader(headerValue.value);
    var headers = headerParseResult.headers;
    for (var header in headers) {
      //print('addding header ${header.name}: ${header.value}');
      message.addHeader(header.name, header.value);
    }
    return headerParseResult;
  }

  void _parseBody(Message message, ImapValue bodyValue) {
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

    // [1].children body parameter parenthesized list
    //   A parenthesized list of attribute/value pairs [e.g., ("foo"
    //   "bar" "baz" "rag") where "bar" is the value of "foo" and
    //   "rag" is the value of "baz"] as defined in [MIME-IMB].

    // [2]body id
    //   A string giving the content id as defined in [MIME-IMB].

    // [3]body description
    //   A string giving the content description as defined in
    //   [MIME-IMB].

    // [4]body encoding
    //   A string giving the content transfer encoding as defined in
    //   [MIME-IMB].

    // [5]body size
    //   A number giving the size of the body in octets.  Note that
    //   this size is the size in its transfer encoding and not the
    //   resulting size after any decoding.

    // [6]
    // A body type of type MESSAGE and subtype RFC822 contains,
    // immediately after the basic fields, the envelope structure,
    // body structure, and size in text lines of the encapsulated
    // message.

    // A body type of type TEXT contains, immediately after the basic
    // fields, the size of the body in text lines.  Note that this
    // size is the size in its content transfer encoding and not the
    // resulting size after any decoding.
    var children = bodyValue.children;
    //print("body: $children");
    var body = Body();
    var isBodyTypeSet = false;
    for (var child in children) {
      if (child.children != null && child.children.length >= 6) {
        // this is a structure value
        var structs = child.children;
        var size = int.tryParse(structs[5].value);
        var structure = BodyStructure(
            structs[0].value,
            structs[1].value,
            _checkForNil(structs[2].value),
            _checkForNil(structs[3].value),
            structs[4].value,
            size);
        if (structs.length > 6) {
          structure.numberOfLines = int.tryParse(structs[6].value);
        }
        var attributeValues = structs[1].children;
        if (attributeValues != null && attributeValues.length > 1) {
          for (var i = 0; i < attributeValues.length; i += 2) {
            structure.addAttribute(
                attributeValues[i].value, attributeValues[i + 1].value);
          }
        }
        body.addStructure(structure);
      } else if (!isBodyTypeSet) {
        // this is the type:
        isBodyTypeSet = true;
        body.type = child.value;
      }
      message.body = body;
    }
  }

  /// parses the envelope structure of a message
  void _parseEnvelope(Message message, ImapValue envelopeValue) {
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
    var children = envelopeValue.children;
    //print("envelope: $children");
    if (children != null && children.length >= 10) {
      message.date = children[0].value;
      message.subject = children[1].value;
      message.from = _parseAddress(children[2]);
      message.sender = _parseAddress(children[3]);
      message.replyTo = _parseAddress(children[4]);
      message.to = _parseAddress(children[5]);
      message.cc = _parseAddress(children[6]);
      message.bcc = _parseAddress(children[7]);
      message.inReplyTo = children[8].value;
      message.messageId = children[9].value;
      message.addHeader('Date', children[0].value);
      message.addHeader('Subject', children[1].value);
      message.addHeader('In-Reply-To', children[8].value);
      message.addHeader('Message-ID', children[9].value);
    }
  }

  Address _parseAddress(ImapValue addressValue) {
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
        addressValue.children.length < 4) {
      return null;
    }
    var children = addressValue.children;
    return Address.fromEnvelope(
        _checkForNil(children[0].value),
        _checkForNil(children[1].value),
        _checkForNil(children[2].value),
        _checkForNil(children[3].value));
  }

  String _checkForNil(String value) {
    if (value == 'NIL') {
      return null;
    }
    return value;
  }
}
