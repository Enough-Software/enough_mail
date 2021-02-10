import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';

class MailSignature {

	dynamic _private_key;
	String  _domain;
	String  _selector;
	Map     _options;
	dynamic _canonicalized_headers_relaxed;
	
	MailSignature(String privateKey, this._domain, this._selector){
		_private_key = RSAKeyParser().parse(privateKey);
		
    _options = {
			'use_dkim'                   : true,
			'use_domainKeys'             : false,
			'identity'                   : null,
			'dkim_body_canonicalization' : 'relaxed',
			'dk_canonicalization'        : 'nofws',
			'dkim_hash'                  : 'sha256',
			'signed_headers'             : [
				'mime-version',
				'from',
				'to',
				'subject',
				'reply-to'
      ]
    };
		
		if (_options.containsKey('signed_headers')) {
      for (var i = 0; i < _options['signed_headers'].length; i++) {
        _options['signed_headers'][i] = _options['signed_headers'][i].toLowerCase();
      }
		}
	}
	
	Map<String, String> _dkim_canonicalize_headers_relaxed(String sHeaders){

		var aHeaders = {};
				sHeaders = sHeaders.replaceAll(RegExp('\n\s+'), ' ');
		
		var lines = sHeaders.split('\r\n');
		
		for (var line in lines){
			line = line.replaceAll(RegExp('/\s+/'), ' ');
			
			if (line.isNotEmpty) {
				var vals         = line.split(':');
				var header_type  = vals.first.trim().toLowerCase();
				var header_value = vals.last.trim().toLowerCase();
				
				if (_options['signed_headers'].contains(header_type)|| header_type == 'dkim-signature') {
					aHeaders[header_type] = '$header_type:$header_value';
				}
			}
		}
		
		return Map<String, String>.from(aHeaders);
	}
	
	String _dkim_canonicalize_body_simple(String body){
		
		while (body.substring(body.length - 4) == '\r\n\r\n'){
			body = body.substring(body.length - 2);
		}
		
		// must end with CRLF anyway
		if (body.substring(body.length - 2) != '\r\n') {
			body += '\r\n';
		}
		
		return body;
	}
	
	String _dkim_canonicalize_body_relaxed(String body) {
		
		var lines = body.split('\r\n');
		
		for (var i = 0; i < lines.length; i++) {
			lines[i] =  lines[i].trimRight().replaceAll(RegExp('\s+'), ' ');
		}
		
		return _dkim_canonicalize_body_simple(lines.join('\r\n'));
	}
	

	String _dk_canonicalize_simple(String body, String sHeaders) {

    var aHeaders = sHeaders.split('\r\n');

		for (var i = 0; i < aHeaders.length; i++) {
			
			var line             = aHeaders[i];
      var c                = String.fromCharCode(line.codeUnitAt(0));
      var is_signed_header = true;

      if(!['\r', '\n', '\t', ' '].contains(c)){
      
        var h = line.split(':');
        var header_type = h.first.trim().toLowerCase();
        
        // keep only signature headers
        if (_options['signed_headers'].contains(header_type)) {
          is_signed_header = true;
        } else {
          aHeaders[i]      = null;
          is_signed_header = false;
        }
      } else {
        // do not keep if it belongs to an unwanted header
        if (!is_signed_header){
          aHeaders[i]      = null;
        }
      }
      
		}

		var mail = aHeaders.where((e) => e != null).join('\r\n') + '\r\n\r\n' + body + '\r\n';
		
    while (body.substring(mail.length - 4) == '\r\n\r\n'){
			mail = mail.substring(mail.length - 2);
		}
		
		return mail;
	}

	String _get_dkim_header(String body) {	
		body = _options['dkim_body_canonicalization'] == 'simple' ?
           _dkim_canonicalize_body_simple(body) : 
           _dkim_canonicalize_body_relaxed(body);

		var bh     = base64.encode(sha256.convert(body.codeUnits).bytes).trimRight();
		var i_part = _options['identity'] == null ? '' : ' i=' + _options['identity'] + ';\r\n\t';
		
		var dkim_header =
			'DKIM-Signature: ' + 
				'v=1;\r\n\t' + 
				'a=rsa-'  +  _options['dkim_hash']  +  ';\r\n\t' +
				'q=dns/txt;' + '\r\n\t' + 
				's=' + _selector + ';\r\n\t' + 
				't=' + (DateTime.now().millisecondsSinceEpoch / 100).floor().toString() + ';\r\n\t' + 
				'c=relaxed/' + _options['dkim_body_canonicalization'] + ';\r\n\t' + 
				'h=' + _canonicalized_headers_relaxed.keys.join(':') + ';\r\n\t' + 
				'd='+ _domain + ';' + '\r\n\t' + i_part + 
				'bh=' + bh + ';' + '\r\n\t' + 
				'b=';

		var canonicalized_dkim_header = _dkim_canonicalize_headers_relaxed(dkim_header);
		var to_be_signed              = _canonicalized_headers_relaxed.values.join('\r\n') + '\r\n' + canonicalized_dkim_header['dkim-signature'];

		if (_options['dkim_hash'] == 'sha256') {
      try {

        // Don't know why the Signer forces to have the public key for signing
        final sign = Signer(RSASigner(RSASignDigest.SHA256, publicKey: RSAKeyParser().parse('''
-----BEGIN PUBLIC KEY-----
MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCqGKukO1De7zhZj6+H0qtjTkVxwTCpvKe4eCZ0
FPqri0cb2JZfXJ/DgYSF6vUpwmJG8wVQZKjeGcjDOL5UlsuusFncCzWBQ7RKNUSesmQRMSGkVb1/
3j+skZ6UtW+5u09lHNsj6tQ51s1SPrCBkedbNf0Tp0GbMJDyR4e9T04ZZwIDAQAB
-----END PUBLIC KEY-----
        '''), privateKey: _private_key)).sign(to_be_signed).base64;

        dkim_header += sign.trimRight() + '\r\n';
      } catch (e) {
        print('Could not sign e-mail with DKIM : ' + to_be_signed + '\n\n$e');
        dkim_header = '';
      }

		} else {
			throw 'Unsupported dkim_hash value: ' + _options['dkim_hash'];
		}

		return dkim_header;
	}
	
	String get_signed_headers(String body, String headers) {

    _canonicalized_headers_relaxed = _dkim_canonicalize_headers_relaxed(headers);

		// ONLY DKIM BECAUSE OF SHA1
		if (_canonicalized_headers_relaxed.isNotEmpty && _options['use_dkim']) {
		  return _get_dkim_header(body);
		} else {
			throw 'No headers found to sign the e-mail with !';
		}
		
	}

}