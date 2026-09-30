import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:encrypter_plus/encrypter_plus.dart';
import 'package:pointycastle/pointycastle.dart' show RSAPrivateKey;

import '../../message_builder.dart';
import '../../mime_message.dart';
import 'non_nullable.dart';

/// Extends Message Builder with signature methods
extension MailSignature on MessageBuilder {
  static final RSAKeyParser _rsaKeyParser = RSAKeyParser();

  /// The headers that are covered by the signature (RFC 6376 section 5.4),
  /// a header that is missing in the message is signed as empty.
  static const List<String> _signedHeaders = [
    'from',
    'to',
    'cc',
    'subject',
    'date',
    'message-id',
    'mime-version',
    'content-type',
  ];
  static const String _crlf = '\r\n';
  static const String _headerName = 'DKIM-Signature';

  String _cleanWhiteSpaces(String target) =>
      target.replaceAll(RegExp(r'\s+', multiLine: true), ' ');
  String _cleanLineBreaks(String target) {
    final parts = target
        .replaceAll(_crlf, '\n')
        .replaceAll('\n', _crlf)
        .split(_crlf);

    for (var i = 0; i < parts.length; i++) {
      parts[i] = _cleanWhiteSpaces(parts[i]).trimRight();
    }

    return parts.join(_crlf);
  }

  int get _secondsSinceEpoch =>
      (DateTime.now().millisecondsSinceEpoch / 1000).floor();

  // The whole canonicalized body is hashed: a body length limit (l=) allows
  // appending arbitrary content to a signed message and made the hash fail
  // for short or non-ASCII bodies.
  Header _createDkimHeader(String body, String? domain, String? selector) =>
      Header(
        _headerName,
        'v=1; a=rsa-sha256; c=relaxed/relaxed; q=dns/txt; '
        't=$_secondsSinceEpoch; d=$domain; s=$selector; '
        'h=${_signedHeaders.join(':')}; '
        'bh=${_hash(body)}; '
        'b=',
      );

  String _hash(String target) =>
      base64.encode(sha256.convert(utf8.encode(target)).bytes);
  String _relaxedHeaderValue(Header head) {
    final headValue = head.value?.replaceAll(RegExp(r'\r|\n'), ' ') ?? '';

    return '${head.lowerCaseName}:'
        '${_cleanWhiteSpaces(headValue).trim()}$_crlf';
  }

  String _relaxedHeader(List<Header> headers) {
    final relaxed = StringBuffer();
    // RFC 6376 section 5.4.2: in the order of the h= tag, using the last
    // instance of a header when it occurs more than once
    for (final name in _signedHeaders) {
      final head = headers.lastWhere(
        (h) => h.lowerCaseName == name,
        orElse: () => Header(name, null),
      );
      if (head.value != null) {
        relaxed.write(_relaxedHeaderValue(head));
      }
    }

    return _cleanLineBreaks(relaxed.toString());
  }

  // Use to see existence of escape characters
  // void _debugTrace(String target) {
  //   print(target
  //       .replaceAll(' ', '<SP>')
  //       .replaceAll('\r', '<CR>')
  //       .replaceAll('\n', '<LF>\n'));
  // }

  String _relaxedBody(String body) {
    final cleaned = _cleanLineBreaks(body).trimRight();

    return cleaned.isEmpty ? '' : cleaned + _crlf;
  }

  String _sign(String privateKeyText, String value) {
    final privateKey = _rsaKeyParser.parse(privateKeyText) as RSAPrivateKey?;
    final data = utf8.encode(value);

    return RSASigner(
      RSASignDigest.SHA256,
      privateKey: privateKey,
    ).sign(data).base64;
  }

  /// Signs the builder with the given [privateKey]
  ///
  /// Adds the signature to the `DKIM-Signature` message header
  bool sign({required String privateKey, String? domain, String? selector}) {
    final msg = buildMimeMessage();
    final body = _relaxedBody(msg.renderMessage(renderHeader: false));
    final header = _relaxedHeader(
      msg.headers.toValueOrThrow('no headers found'),
    );
    final dkim = _relaxedHeaderValue(_createDkimHeader(body, domain, selector));
    final signature = dkim.trim() + _sign(privateKey, (header + dkim).trim());

    addHeader(_headerName, signature.substring(_headerName.length + 1).trim());

    return true;
  }
}
