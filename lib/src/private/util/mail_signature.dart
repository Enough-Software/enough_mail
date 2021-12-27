import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/pointycastle.dart' show RSAPrivateKey;

import '../../message_builder.dart';
import '../../mime_message.dart';

/// Extends Message Builder with signature methods
extension MailSignature on MessageBuilder {
  static final RSAKeyParser _rsaKeyParser = RSAKeyParser();
  static const List<String> _signedHeaders = [
    'from' /*, 'to', 'mime-version'*/
  ];
  static const int _bodyLength = 72; // Fails over >76
  static const String _crlf = '\r\n';
  static const String _headerName = 'DKIM-Signature';

  String _cleanWhiteSpaces(String target) =>
      target.replaceAll(RegExp(r'\s+', multiLine: true), ' ');
  String _cleanLineBreaks(String target) {
    final parts =
        target.replaceAll(_crlf, '\n').replaceAll('\n', _crlf).split(_crlf);

    for (var i = 0; i < parts.length; i++) {
      parts[i] = _cleanWhiteSpaces(parts[i]).trimRight();
    }

    return parts.join(_crlf);
  }

  int get _secondsSinceEpoch =>
      (DateTime.now().millisecondsSinceEpoch / 1000).floor();

  Header _createDkimHeader(String body, String? domain, String? selector) =>
      Header(
        _headerName,
        '''
        v=1; t=$_secondsSinceEpoch;
        d=$domain; s=$selector;
        h=${_signedHeaders.join(':')};
        q=dns/txt;
        l=$_bodyLength;
        c=relaxed/relaxed; a=rsa-sha256;
        bh=${_hash(body.substring(0, _bodyLength))};
        b=
      '''
            .replaceAll(RegExp(r'^ +', multiLine: true), ''),
      );

  String _hash(String target) =>
      base64.encode(sha256.convert(utf8.encode(target)).bytes);
  String _relaxedHeaderValue(Header head) {
    final headValue = head.value?.replaceAll(RegExp(r'\r|\n'), ' ') ?? '';
    return '${head.lowerCaseName}:'
        '${_cleanWhiteSpaces(headValue).trim()}$_crlf';
  }

  bool _isSignedHeader(Header head) =>
      _signedHeaders.contains(head.lowerCaseName);

  String _relaxedHeader(List<Header> headers) {
    final relaxed = StringBuffer();

    for (final head in headers.where(_isSignedHeader)) {
      relaxed.write(_relaxedHeaderValue(head));
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
    final data = utf8.encode(value) as Uint8List;
    return RSASigner(RSASignDigest.SHA256, privateKey: privateKey)
        .sign(data)
        .base64;
  }

  /// Signs the builder with the given [privateKey]
  ///
  /// Adds the signature to the `DKIM-Signature` message header
  bool sign({required String privateKey, String? domain, String? selector}) {
    final msg = buildMimeMessage();
    final body = _relaxedBody(msg.renderMessage(renderHeader: false));
    final header = _relaxedHeader(msg.headers!);
    final dkim = _relaxedHeaderValue(_createDkimHeader(body, domain, selector));
    final signature = dkim.trim() + _sign(privateKey, (header + dkim).trim());

    addHeader(_headerName, signature.substring(_headerName.length + 1).trim());

    return true;
  }
}
