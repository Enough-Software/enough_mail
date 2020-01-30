/// An email address can consist of separate fields
class Address {
  // personal name, [SMTP] at-domain-list (source route), mailbox name, and host name
  String personalName;
  String sourceRoute;
  String mailboxName;
  String hostName;

  String _emailAddress;
  String get emailAddress => _getEmailAddress();
  set emailAddress(value) => _emailAddress = value;

  Address.fromEnvelope(
      this.personalName, this.sourceRoute, this.mailboxName, this.hostName);

  String _getEmailAddress() {
    _emailAddress ??= '$mailboxName@$hostName';
    return _emailAddress;
  }
}
