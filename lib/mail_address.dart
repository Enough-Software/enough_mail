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

  MailAddress(this.personalName, this._email);

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
    var buffer = StringBuffer()
      ..write('"')
      ..write(personalName)
      ..write('" <')
      ..write(email)
      ..write('>');
    return buffer.toString();
  }
}
