import 'package:enough_serialization/enough_serialization.dart';

import 'codecs/mail_codec.dart';

/// An email address can consist of separate fields
class MailAddress extends OnDemandSerializable {
  // personal name, [SMTP] at-domain-list (source route), mailbox name, and host name
  String? personalName;
  String? sourceRoute;
  String? mailboxName;
  String? hostName;

  String _email;
  String get email => _email;
  set email(value) => _email = value;

  /// Checks if this address has a personal name
  bool get hasPersonalName => personalName?.isNotEmpty ?? false;

  MailAddress.empty() : _email = '';

  MailAddress(this.personalName, String email) : _email = email {
    var atIndex = _email.lastIndexOf('@');
    if (atIndex != -1) {
      hostName = _email.substring(atIndex + 1);
      mailboxName = _email.substring(0, atIndex);
    }
  }

  MailAddress.fromEnvelope(
      this.personalName, this.sourceRoute, this.mailboxName, this.hostName)
      : _email = '$mailboxName@$hostName';

  @override
  String toString() {
    if (personalName == null) {
      return email;
    }

    var buffer = StringBuffer();
    writeToStringBuffer(buffer);
    return buffer.toString();
  }

  String encode() {
    final pName = personalName;
    if (pName == null) {
      return email;
    }
    var buffer = StringBuffer()
      ..write('"')
      ..write(MailCodec.quotedPrintable.encodeHeader(pName, fromStart: true))
      ..write('" <')
      ..write(email)
      ..write('>');
    return buffer.toString();
  }

  void writeToStringBuffer(StringBuffer buffer) {
    if (personalName != null && personalName!.isNotEmpty) {
      buffer
        ..write('"')
        ..write(personalName)
        ..write('" ');
    }
    buffer
      ..write('<')
      ..write(email)
      ..write('>');
  }

  /// Searches the [searchForList] addresses in the [searchInList] list.
  /// Set [handlePlusAliases] to `true` in case plus aliases should be checked, too.
  /// Set [removeMatch] to `true` in case the matching address should be removed from the [searchInList] list.
  /// Set [useMatchPersonalName] to `true` to return the personal name from the [searchInList] in the returned match. By default the personal name is retrieved from the matching entry in [searchForList].
  static MailAddress? getMatch(
      List<MailAddress> searchForList, List<MailAddress>? searchInList,
      {bool handlePlusAliases = false,
      bool removeMatch = false,
      bool useMatchPersonalName = false}) {
    for (final searchFor in searchForList) {
      final searchForEmailAddress = searchFor.email.toLowerCase();
      if (searchInList?.isNotEmpty ?? false) {
        MailAddress match;
        for (var i = 0; i < searchInList!.length; i++) {
          final potentialMatch = searchInList[i];
          final matchAddress = getMatchingEmail(
              searchForEmailAddress, potentialMatch.email.toLowerCase(),
              allowPlusAlias: handlePlusAliases);
          if (matchAddress != null) {
            match = useMatchPersonalName
                ? potentialMatch
                : MailAddress(searchFor.personalName, matchAddress);
            if (removeMatch) {
              searchInList.removeAt(i);
            }
            return match;
          }
        }
      }
    }
    return null;
  }

  /// Checks if both email addresses [original] and [check] match and returns the match.
  /// Set [allowPlusAlias] if plus aliases should be checked, so that `name+alias@domain` matches the original `name@domain`.
  static String? getMatchingEmail(String original, String check,
      {bool allowPlusAlias = false}) {
    if (check == original) {
      return check;
    } else if (allowPlusAlias) {
      final plusIndex = check.indexOf('+');
      if (plusIndex > 1) {
        final start = check.substring(0, plusIndex);
        if (original.startsWith(start)) {
          final atIndex = check.lastIndexOf('@');
          if (atIndex > plusIndex &&
              original.endsWith(check.substring(atIndex))) {
            return check;
          }
        }
      }
    }
    return null;
  }

  @override
  void read(Map<String, dynamic> attributes) {
    personalName = attributes['personalName'];
    email = attributes['email'];
  }

  @override
  void write(Map<String, dynamic> attributes) {
    attributes['personalName'] = personalName;
    attributes['email'] = email;
  }

  @override
  int get hashCode => _email.hashCode + (personalName?.hashCode ?? 0);

  @override
  bool operator ==(Object o) =>
      o is MailAddress && o._email == _email && o.personalName == personalName;
}
