import 'package:enough_serialization/enough_serialization.dart';

import 'codecs/mail_codec.dart';

/// An email address can consist of separate fields
class MailAddress extends OnDemandSerializable {
  /// Creates a new mail address
  MailAddress(this.personalName, this.email) {
    final atIndex = email.lastIndexOf('@');
    if (atIndex != -1) {
      hostName = email.substring(atIndex + 1);
      mailboxName = email.substring(0, atIndex);
    }
  }

  /// Creates an empty mail address
  MailAddress.empty() : email = '';

  /// Creates a new mail address
  MailAddress.fromEnvelope(
      this.personalName, this.sourceRoute, this.mailboxName, this.hostName)
      : email = '$mailboxName@$hostName';

  /// personal name
  String? personalName;

  /// `SMTP` at-domain-list (source route)
  String? sourceRoute;

  /// mailbox name
  String? mailboxName;

  /// host name
  String? hostName;

  /// email address
  String email;

  /// Checks if this address has a personal name
  bool get hasPersonalName => personalName?.trim().isNotEmpty ?? false;

  /// Checks if this address has not a personal name
  bool get hasNoPersonalName => !hasPersonalName;

  @override
  String toString() {
    if (personalName == null) {
      return email;
    }

    final buffer = StringBuffer();
    writeToStringBuffer(buffer);
    return buffer.toString();
  }

  /// Encodes this mail address
  String encode() {
    if (hasNoPersonalName) {
      return email;
    }
    final pName = personalName!;
    final buffer = StringBuffer()
      ..write('"')
      ..write(MailCodec.quotedPrintable.encodeHeader(pName, fromStart: true))
      ..write('" <')
      ..write(email)
      ..write('>');
    return buffer.toString();
  }

  /// Encodes this mail address into the given [buffer]
  void writeToStringBuffer(StringBuffer buffer) {
    if (hasPersonalName) {
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
  ///
  /// Set [handlePlusAliases] to `true` in case plus aliases should be checked.
  /// Set [removeMatch] to `true` in case the matching address should be
  /// removed from the [searchInList] list.
  /// Set [useMatchPersonalName] to `true` to return the personal name from the
  /// [searchInList] in the returned match. By default the personal name is
  /// retrieved from the matching entry in [searchForList].
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

  /// Checks if both email addresses [original] and [check] match and
  /// returns the match.
  ///
  /// Set [allowPlusAlias] if plus aliases should be checked, so that
  /// `name+alias@domain` matches the original `name@domain`.
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
  int get hashCode => email.hashCode + (personalName?.hashCode ?? 0);

  @override
  bool operator ==(Object other) =>
      other is MailAddress &&
      other.email == email &&
      other.personalName == personalName;
}
