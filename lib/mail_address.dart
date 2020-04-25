import 'package:enough_mail/codecs/mail_codec.dart';

/// An email address can consist of separate fields
class MailAddress {
  // personal name, [SMTP] at-domain-list (source route), mailbox name, and host name
  String personalName;
  String sourceRoute;
  String mailboxName;
  String hostName;

  String _email;
  String get email => _getEmailAddress();
  set email(value) => _email = value;

  MailAddress(this.personalName, this._email) {
    var atIndex = _email.lastIndexOf('@');
    if (atIndex != -1) {
      hostName = _email.substring(atIndex + 1);
      mailboxName = _email.substring(0, atIndex);
    }
  }

  MailAddress.empty();

  MailAddress.fromEnvelope(
      this.personalName, this.sourceRoute, this.mailboxName, this.hostName);

  String _getEmailAddress() {
    _email ??= '$mailboxName@$hostName';
    return _email;
  }

  @override
  String toString() {
    if (personalName == null) {
      return email;
    }

    var buffer = StringBuffer();
    write(buffer);
    return buffer.toString();
  }

  String encode() {
    if (personalName == null) {
      return email;
    }
    var buffer = StringBuffer()
      ..write('"')
      ..write(
          MailCodec.quotedPrintable.encodeHeader(personalName, fromStart: true))
      ..write('" <')
      ..write(email)
      ..write('>');
    return buffer.toString();
  }

  void write(StringBuffer buffer) {
    buffer
      ..write('"')
      ..write(personalName)
      ..write('" <')
      ..write(email)
      ..write('>');
  }
}
