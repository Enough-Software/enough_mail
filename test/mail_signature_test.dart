import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/src/private/util/mail_signature.dart';
import 'package:test/test.dart';

// A throw-away 2048 bit RSA key generated for this test only.
const _privateKey = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEpQIBAAKCAQEAxv9f8xWRb9e2qYXFZ742o3wjzdjaTbV7RxmQB5df5GXqOeNP
kBIaWauEQD8uWLv368yIm+ugBtPpBXJZjQi80F99fR/2kV7fv9jpepRrh9NwTyyx
fSp6+O8RAAZxh2bGR/suAgH2cKfJm8N5eXDibRv/vBoOerlKkm1av7vJ4KDqOBxu
C7DiJKXkH4AW61pNGQqt/RrxN0mVOY+qDDFJ7xF3AGZamjPHM8hXtFW5+mhlpygv
gmxu5qEVbZKoF6JbEuKL6ocazAlHg2kiZjccMz6JV736Ui2U/7VrZciPx6KXhrHu
S59J/Dk3g7wjjm+3lDU2XpRIZ4ldNcR/1mirowIDAQABAoIBAAgC6NSyDgWVqzVX
qqMBk4uMiE9VpzMejblG6gmmfJ0ZMmqt6VqFEA46HaDEhdPbRWoJPmPXcHP/DyuK
0o9DtBLaWd/7R0ynOnA+GFTLKbvxbDiBftV74sM5+4kVcC6hvivQjMqfnVGSUf4+
XNDhzGdCsE6T6NPkSzdFoTQXKFOba4Nqb/GZPzrxCYQ1vkNwdN+Jxr76yfBtuviF
aYhEGFRveU37IKH8AWXXE1oSGr/kVPHkIlod3KdpTnzATIjJkGMf0SobLDJlfmfx
3i9bPSX8XZ9O5zL1oHlLBWYzSFYekkGD20DtEXpjhb2xZg9xw9P9HjqcKTUn1LLe
0A4UE/kCgYEA6YLWq8y2aA1Z/XXfAxCEEryBuHwM0EHzkXdMai15imVm3BQyDY2S
axifq5LAr319SpciXqf+Lutqro8Pgr2C62KHVrHXgs401R7fl4QXQkhgQpI/Hkej
3E3GISzACmu0fEu5F1H8J+eFl5nProYFbBCwpQuVo/OBR3fbsj7lno0CgYEA2imc
+rLaLvIb6UIlIKiakT49sY2aXndtKl1/Rs3UXnHp64WwAcJQjeVqSTDI+2E3UNl/
3du6CWlXrZ/TWJaInGg+vKpT6jq82MUC7NTfqsgqbPLhkgXF1iE/GqTclbCk3qKg
xm6ppnOGcFlzOXkmfOknAxgvmn99rra8NJcRvu8CgYEA14HNJZk07ysDVoymWWmw
uqoG/oBeQwXbCPGVMJjvhu62035AA4oZC4YaNnqmIlAqheCd88YPLLZQKvIVWpAU
d7DjPvu67hnpYJexu2BJJv8s98OJRSTQ8c1FgfCO/A8S73PjSsZ7dUiTXqqxpVxD
PMzaejgKztk5AwB3XjX2LTECgYEApJP/+KA0OHYs2CsuFxUahbeOkwNgESPHFs6x
1ZgxPY5yCVsxDCKq4mDPbad/9yO/tx5dd+Dq127A1hpcNdhZ9qQtr+ZOp8Tn8h+t
tTxh/1RBrS8NPDteo8sw78ivH73CorHM1+Vj1k4QfXD9m73paxH4fD0irErBZaw1
DvdoS8ECgYEA5B3JUSl9LUXphK2QRv+oL9CNEPYObxnAtPS5U7yXcrj/OS2Z3yBY
+fqDEVanIpqJXyQctSlKKhUNWJrUqP7ONYSIpBeeIVz5+lmeq1FAEfqSNJAGxDSx
dXXkw7ARQqip+epV428IcxckR3gZed9EqF17DqESSijiLKOQFiGLWKc=
-----END RSA PRIVATE KEY-----
''';

void main() {
  test('sign() covers the whole body and the relevant headers', () {
    final builder = MessageBuilder()
      ..from = const [MailAddress('Me', 'me@example.com')]
      ..to = const [MailAddress('You', 'you@example.com')]
      ..subject = 'Signed'
      ..text = 'Short bödy'
      ..addBinary(
        Uint8List.fromList([1, 2, 3]),
        MediaSubtype.applicationOctetStream.mediaType,
        filename: 'a.bin',
      );
    expect(
      builder.sign(
        privateKey: _privateKey,
        domain: 'example.com',
        selector: 's1',
      ),
      isTrue,
    );
    final message = builder.buildMimeMessage();
    final dkim = message.getHeaderValue('DKIM-Signature');
    expect(dkim, isNotNull);
    expect(dkim, isNot(contains('l=')));
    expect(dkim, contains('h=from:to:cc:subject:date:message-id'));
    expect(dkim, contains('bh='));
    expect(dkim, matches(RegExp(r'b=[A-Za-z0-9+/=]+$')));
    // building the message again for sending must not duplicate the text
    expect(
      message.parts?.where((p) => p.mediaType.sub == MediaSubtype.textPlain),
      hasLength(1),
    );
  });

  test('plus aliases only match the exact base address', () {
    expect(
      MailAddress.getMatchingEmail(
        'user@example.com',
        'user+tag@example.com',
        allowPlusAlias: true,
      ),
      'user+tag@example.com',
    );
    expect(
      MailAddress.getMatchingEmail(
        'admin@example.com',
        'ad+min@example.com',
        allowPlusAlias: true,
      ),
      isNull,
    );
  });

  test('random ids come from a secure source and differ', () {
    final ids = {for (var i = 0; i < 100; i++) MessageBuilder.createRandomId()};
    expect(ids, hasLength(100));
  });
}
