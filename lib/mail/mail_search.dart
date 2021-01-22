import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail/imap/imap_search.dart';

/// Abstracts a typical mail search
class MailSearch {
  /// The query text
  final String query;

  /// Which message fields should be used for this query.
  final SearchQueryType queryType;

  /// Which message types should be used for this query - defaults to any.
  final SearchMessageType messageType;

  /// From which internal date onward a message matches
  final DateTime since;

  /// Until which internal date a message matches
  final DateTime before;

  /// From which internal sent date a message matches
  final DateTime sentSince;

  /// Until wich internal sent date a message matches
  final DateTime sentBefore;

  /// Creates a new search for [query] in the fields defined by [queryType].
  /// Optionally you can also define what kind of messages to search with the [messageType],
  /// the internal date since a message has been received with [since],
  /// the internal date before a message has been received with [before],
  /// the internal date since a message has been sent with [sentSince],
  /// the internal date before a message has been sent with [sentBefore],
  MailSearch(this.query, this.queryType,
      {this.messageType,
      this.since,
      this.before,
      this.sentSince,
      this.sentBefore});

  /// Checks a new incoming message if it matches this query
  bool matches(MimeMessage message) {
    var matchesQuery = query?.isEmpty ?? true;
    if (!matchesQuery) {
      // the query is not empty
      final queryText = query.toLowerCase();
      switch (queryType) {
        case SearchQueryType.subject:
          matchesQuery = _matchesSubject(queryText, message);
          break;
        case SearchQueryType.from:
          matchesQuery = _matchesFrom(queryText, message);
          break;
        case SearchQueryType.to:
          matchesQuery = _matchesTo(queryText, message);
          break;
        case SearchQueryType.body:
          matchesQuery = _textContains(queryText, message.bodyRaw);
          break;
        case SearchQueryType.allTextHeaders:
          matchesQuery = _matchesSubject(queryText, message) ||
              _matchesFrom(queryText, message) ||
              _matchesTo(queryText, message);
          break;
      }
      if (!matchesQuery) {
        return false;
      }
    }
    if (before != null) {
      final date = message.decodeDate();
      if (date.isAfter(before)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesSubject(String queryText, MimeMessage message) {
    return message.decodeSubject()?.toLowerCase()?.contains(queryText) ?? false;
  }

  bool _matchesFrom(String queryText, MimeMessage message) {
    return _matchesAddresses(queryText, message.from);
  }

  bool _matchesTo(String queryText, MimeMessage message) {
    return _matchesAddresses(queryText, message.to) ||
        _matchesAddresses(queryText, message.cc);
  }

  bool _matchesAddresses(String queryText, List<MailAddress> addresses) {
    if (addresses?.isEmpty ?? true) {
      return false;
    }
    for (final address in addresses) {
      if (_textContains(queryText, address.email) ||
          _textContains(queryText, address.personalName)) {
        return true;
      }
    }
    return false;
  }

  bool _textContains(String queryText, String text) {
    if (text == null) {
      return false;
    }
    return text.toLowerCase().contains(queryText);
  }
}
