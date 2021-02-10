import 'package:enough_mail/enough_mail.dart';
import 'dart:io';
import 'package:test/test.dart';
import 'package:enough_mail/message_builder.dart';

void main() {
  var msg = MessageBuilder();

  msg.to      = [MailAddress('Test', 'test@test.de')];
  msg.from    = [MailAddress('Test', 'test@test.de')];
  msg.subject = 'Test';

  msg.addText('TEST');

  msg.sign(File('test/smtp/key_private.pem').readAsStringSync(), 'test.de', 'dmkey');

}