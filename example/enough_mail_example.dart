import 'package:enough_mail/enough_mail.dart';

void main() async {
  var client  = ImapClient(isLogEnabled: true);
  await client.connectToServer('imap.example.com', 993, isSecure: true);
  var loginResponse = await client.login('user.name', 'secret');
  if (loginResponse.isOkStatus) {
    var listResponse = await client.listMailboxes();
    if (listResponse.isOkStatus) {
      print('mailboxes: ${listResponse.result}');
    }
  }

}
