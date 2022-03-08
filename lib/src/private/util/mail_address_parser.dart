import '../../codecs/mail_codec.dart';
import '../../mail_address.dart';
import 'ascii_runes.dart';
import 'word.dart';

/// Helps parsing email addresses
class MailAddressParser {
  MailAddressParser._();

  /// Parses one or more addresses given in the [emailText].
  static List<MailAddress> parseEmailAddresses(String? emailText) {
    if (emailText == null || emailText.isEmpty) {
      return <MailAddress>[];
    }
    /*
    cSpell:disable
    TODO: the current email parsing implementation is quite naive
    Here is a list of valid email addresses (without name):
    Abc@example.com                               (English, ASCII)
    Abc.123@example.com                           (English, ASCII)   
    user+mailbox/department=shipping@example.com  (English, ASCII)
    !#$%&'*+-/=?^_`.{|}~@example.com              (English, ASCII)
    "Abc@def"@example.com                         (English, ASCII)
    "Fred Bloggs"@example.com                     (English, ASCII)
    "Joe.\\Blow"@example.com                      (English, ASCII)
    simple@example.com
    very.common@example.com
    disposable.style.email.with+symbol@example.com
    other.email-with-hyphen@example.com
    fully-qualified-domain@example.com
    user.name+tag+sorting@example.com (may go to user.name@example.com 
    inbox depending on mail server)
    x@example.com (one-letter local-part)
    example-indeed@strange-example.com
    admin@mailserver1 (local domain name with no TLD, although ICANN highly 
    discourages dotless email addresses)
    example@s.example (see the List of Internet top-level domains)
    " "@example.org (space between the quotes)
    "john..doe"@example.org (quoted double dot)
    mailhost!username@example.org (bangified host route used for uucp mailers)
    user%example.com@example.org (% escaped mail route to user@example.com via 
    example.org)
    用户@例子.广告               (Chinese, Unicode)
    अजय@डाटा.भारत               (Hindi, Unicode)
    квіточка@пошта.укр          (Ukrainian, Unicode)
    θσερ@εχαμπλε.ψομ            (Greek, Unicode)
    Dörte@Sörensen.example.com  (German, Unicode)
    коля@пример.рф              (Russian, Unicode)
    Latin alphabet with diacritics: Pelé@example.com
    Greek alphabet: δοκιμή@παράδειγμα.δοκιμή
    Traditional Chinese characters: 我買@屋企.香港
    Japanese characters: 二ノ宮@黒川.日本
    Cyrillic characters: медведь@с-балалайкой.рф
    Devanagari characters: संपर्क@डाटामेल.भारत
    cSpell:enable
    */
    final addresses = <MailAddress>[];
    final addressParts = _splitAddressParts(emailText);
    for (final addressPart in addressParts) {
      //print('processing [$addressPart]');
      final emailWord = _findEmailAddress(addressPart);
      if (emailWord == null) {
        print(
            'Warning: no valid email address: [$addressPart] in [$emailText]');
        continue;
      }
      var name = emailWord.startIndex == 0
          ? null
          : addressPart.substring(0, emailWord.startIndex - 1).trim();
      if (name != null) {
        if (name.startsWith('"') && name.endsWith('"')) {
          name = name.substring(1, name.length - 1);
        }
        name = name.replaceAll(r'\"', '"');
        if (name.contains('=?')) {
          name = MailCodec.decodeHeader(name);
        }
      }
      final address = MailAddress(name, emailWord.text);
      addresses.add(address);
    }
    return addresses;
  }

  static List<String> _splitAddressParts(final String text) {
    if (text.isEmpty) {
      return [];
    }
    final result = <String>[];
    final runes = text.runes.toList();
    var isInValue = false;
    var startIndex = 0;
    var valueEndRune = AsciiRunes.runeSpace;
    for (var i = 0; i < text.length; i++) {
      final rune = runes[i];
      if (isInValue) {
        if (rune == valueEndRune) {
          isInValue = false;
        }
      } else {
        if (rune == AsciiRunes.runeComma || rune == AsciiRunes.runeSemicolon) {
          // found a split position
          final textPart = text.substring(startIndex, i).trim();
          result.add(textPart);
          startIndex = i + 1;
        } else if (rune == AsciiRunes.runeDoubleQuote) {
          valueEndRune = AsciiRunes.runeDoubleQuote;
          isInValue = true;
        } else if (rune == AsciiRunes.runeSmallerThan) {
          valueEndRune = AsciiRunes.runeGreaterThan;
          isInValue = true;
        }
      }
    }
    if (startIndex < text.length - 1) {
      final textPart = text.substring(startIndex).trim();
      result.add(textPart);
    }
    return result;
  }

  static Word? _findEmailAddress(String text) {
    final atIndex = text.lastIndexOf('@');
    if (atIndex == -1) {
      return null;
    }
    var isInValue = false;
    var startIndex = 0;
    var endIndex = text.length;
    var valueEndRune = AsciiRunes.runeSpace; // space
    final runes = text.runes.toList();
    var isFoundAtRune = false;
    for (var i = endIndex; --i >= 0;) {
      final rune = runes[i];
      if (isInValue) {
        if (rune == valueEndRune) {
          isInValue = false;
        }
      } else {
        if (rune == AsciiRunes.runeAt) {
          isFoundAtRune = true;
        } else if (!isFoundAtRune) {
          if (rune == AsciiRunes.runeGreaterThan ||
              rune == AsciiRunes.runeSpace) {
            endIndex = i;
          }
        } else if (rune == AsciiRunes.runeSmallerThan ||
            rune == AsciiRunes.runeSpace) {
          startIndex = i + 1;
          break;
        } else if (isFoundAtRune && rune == AsciiRunes.runeDoubleQuote) {
          isInValue = true;
          valueEndRune = AsciiRunes.runeDoubleQuote;
        }
      }
    }
    final email = text.substring(startIndex, endIndex);
    return Word(email, startIndex);
  }
}
