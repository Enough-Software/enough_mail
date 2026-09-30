import 'package:json_annotation/json_annotation.dart';

import 'codecs/mail_codec.dart';
import 'private/util/ascii_runes.dart';
import 'private/util/mail_address_parser.dart';

part 'mail_address.g.dart';

/// An email address can consist of separate fields
@JsonSerializable()
class MailAddress {
  /// Creates a new mail address
  const MailAddress(this.personalName, this.email);

  /// Creates a new mail address
  factory MailAddress.fromEnvelope({
    required String mailboxName,
    required String hostName,
    String? personalName,
  }) {
    if (mailboxName.isEmpty) {
      return MailAddress(personalName, hostName);
    }
    if (hostName.isEmpty) {
      return MailAddress(personalName, mailboxName);
    }

    return MailAddress(personalName, '$mailboxName@$hostName');
  }

  /// Creates a new mail address by parsing the [input].
  ///
  /// Compare [encode]
  factory MailAddress.parse(String input) {
    final parsed = MailAddressParser.parseEmailAddresses(input);
    if (parsed.isEmpty) {
      throw FormatException('for invalid email [$input]');
    }

    return parsed.first;
  }

  /// Creates a new [MailAddress] form the given [json]
  factory MailAddress.fromJson(Map<String, dynamic> json) =>
      _$MailAddressFromJson(json);

  /// Converts this [MailAddress] to JSON
  Map<String, dynamic> toJson() => _$MailAddressToJson(this);

  /// personal name
  final String? personalName;

  /// mailbox name
  String get mailboxName {
    final atIndex = email.lastIndexOf('@');
    if (atIndex != -1) {
      return email.substring(0, atIndex);
    }

    return email;
  }

  /// host name
  String get hostName {
    final atIndex = email.lastIndexOf('@');
    if (atIndex != -1) {
      return email.substring(atIndex + 1);
    }

    return email;
  }

  /// email address
  final String email;

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

  /// Checks that [email] contains no characters that could break out of an
  /// address header or an SMTP envelope address: control characters, `<`,
  /// `>`, `,`, `;` and - unless the local part is quoted - white space.
  ///
  /// This is not a full RFC 5322 syntax check.
  static bool isSafeEmail(String email) {
    final isQuotedLocalPart = email.startsWith('"') && email.contains('"@');
    for (final code in email.codeUnits) {
      if (code < AsciiRunes.runeSpace ||
          code == 127 ||
          code == AsciiRunes.runeSmallerThan ||
          code == AsciiRunes.runeGreaterThan ||
          code == AsciiRunes.runeComma ||
          code == AsciiRunes.runeSemicolon) {
        return false;
      }
      if (code == AsciiRunes.runeSpace && !isQuotedLocalPart) {
        return false;
      }
    }

    return true;
  }

  /// Encodes this mail address
  ///
  /// The personal name is rendered as an RFC 5322 quoted-string, escaping
  /// `"` and `\`, or as an encoded word when it contains non-ASCII text.
  /// Throws an [ArgumentError] when [email] contains characters that would
  /// break the address header, compare [isSafeEmail].
  ///
  /// Compare [MailAddress.parse] to decode an address
  String encode() {
    if (!isSafeEmail(email)) {
      throw ArgumentError.value(
        email,
        'email',
        'contains characters that are not allowed in an address header',
      );
    }
    final personalName = this.personalName;
    if (personalName == null || hasNoPersonalName) {
      return email;
    }
    final name = personalName.trim();
    final encoded = MailCodec.quotedPrintable.encodeHeader(
      name,
      fromStart: true,
    );
    // RFC 5322 section 3.2.4: within a quoted-string the characters " and \
    // have to be escaped as quoted-pairs
    final quoted = encoded == name
        ? name.replaceAll(r'\', r'\\').replaceAll('"', r'\"')
        : encoded;

    return '"$quoted" <$email>';
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
    List<MailAddress> searchForList,
    List<MailAddress>? searchInList, {
    bool handlePlusAliases = false,
    bool removeMatch = false,
    bool useMatchPersonalName = false,
  }) {
    for (final searchFor in searchForList) {
      final searchForEmailAddress = searchFor.email.toLowerCase();
      if (searchInList != null && searchInList.isNotEmpty) {
        MailAddress match;
        for (var i = 0; i < searchInList.length; i++) {
          final potentialMatch = searchInList[i];
          final matchAddress = getMatchingEmail(
            searchForEmailAddress,
            potentialMatch.email.toLowerCase(),
            allowPlusAlias: handlePlusAliases,
          );
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
  static String? getMatchingEmail(
    String original,
    String check, {
    bool allowPlusAlias = false,
  }) {
    if (check == original) {
      return check;
    } else if (allowPlusAlias) {
      final plusIndex = check.indexOf('+');
      final atIndex = check.lastIndexOf('@');
      if (plusIndex > 0 && atIndex > plusIndex) {
        // `name+alias@domain` only matches exactly `name@domain`, a prefix
        // check would let `ad+min@domain` impersonate `admin@domain`
        final withoutAlias =
            check.substring(0, plusIndex) + check.substring(atIndex);
        if (withoutAlias == original) {
          return check;
        }
      }
    }

    return null;
  }

  /// Copies this mail address with the given values
  MailAddress copyWith({String? personalName, String? email}) =>
      MailAddress(personalName ?? this.personalName, email ?? this.email);

  @override
  int get hashCode => email.hashCode + (personalName?.hashCode ?? 0);

  @override
  bool operator ==(Object other) =>
      other is MailAddress &&
      other.email == email &&
      other.personalName == personalName;
}
