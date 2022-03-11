import '../imap/imap_search.dart';
import '../mail_address.dart';
import '../mime_message.dart';
import 'mail_client.dart';

/// Abstracts a typical mail search
class MailSearch {
  /// Creates a new search for [query] in the fields defined by [queryType].
  ///
  /// Optionally you can also define what kind of messages to search
  /// with the [messageType],
  /// the internal date since a message has been received with [since],
  /// the internal date before a message has been received with [before],
  /// the internal date since a message has been sent with [sentSince],
  /// the internal date before a message has been sent with [sentBefore],
  /// the number of messages that are loaded initially with [pageSize]
  /// which defaults to `20`.
  /// the [fetchPreference] for fetching the initial page of messages,
  /// defaults to [FetchPreference.envelope].
  const MailSearch(
    this.query,
    this.queryType, {
    this.messageType,
    this.since,
    this.before,
    this.sentSince,
    this.sentBefore,
    this.pageSize = 20,
    this.fetchPreference = FetchPreference.envelope,
  });

  /// The query text
  final String query;

  /// Which message fields should be used for this query.
  final SearchQueryType queryType;

  /// Which message types should be used for this query - defaults to any.
  final SearchMessageType? messageType;

  /// From which internal date onward a message matches
  final DateTime? since;

  /// Until which internal date a message matches
  final DateTime? before;

  /// From which internal sent date a message matches
  final DateTime? sentSince;

  /// Until which internal sent date a message matches
  final DateTime? sentBefore;

  /// The number of messages that are loaded initially
  final int pageSize;

  /// The fetch preference for loading the search results
  final FetchPreference fetchPreference;

  /// Checks a new incoming [message] if it matches this query
  bool matches(MimeMessage message) {
    var matchesQuery = query.isEmpty;
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
          matchesQuery =
              _textContains(queryText, message.decodeTextPlainPart());
          break;
        case SearchQueryType.allTextHeaders:
          matchesQuery = _matchesSubject(queryText, message) ||
              _matchesFrom(queryText, message) ||
              _matchesTo(queryText, message);
          break;
        case SearchQueryType.fromOrSubject:
          matchesQuery = _matchesSubject(queryText, message) ||
              _matchesFrom(queryText, message);
          break;
        case SearchQueryType.toOrSubject:
          matchesQuery = _matchesSubject(queryText, message) ||
              _matchesTo(queryText, message);
          break;
        case SearchQueryType.fromOrTo:
          matchesQuery = _matchesFrom(queryText, message) ||
              _matchesTo(queryText, message);
          break;
      }
      if (!matchesQuery) {
        return false;
      }
    }
    if (before != null) {
      final date = message.decodeDate() ?? DateTime.now();
      if (date.isAfter(before!)) {
        return false;
      }
    }
    return true;
  }

  bool _matchesSubject(String queryText, MimeMessage message) =>
      message.decodeSubject()?.toLowerCase().contains(queryText) ?? false;

  bool _matchesFrom(String queryText, MimeMessage message) =>
      _matchesAddresses(queryText, message.from);

  bool _matchesTo(String queryText, MimeMessage message) =>
      _matchesAddresses(queryText, message.to) ||
      _matchesAddresses(queryText, message.cc);

  bool _matchesAddresses(String queryText, List<MailAddress>? addresses) {
    if (addresses?.isEmpty ?? true) {
      return false;
    }
    for (final address in addresses!) {
      if (_textContains(queryText, address.email) ||
          _textContains(queryText, address.personalName)) {
        return true;
      }
    }
    return false;
  }

  bool _textContains(String queryText, String? text) {
    if (text == null) {
      return false;
    }
    return text.toLowerCase().contains(queryText);
  }

  /// Copies this search with the specified different parameters.
  MailSearch copyWith(
          {String? query,
          SearchQueryType? queryType,
          SearchMessageType? messageType,
          DateTime? before,
          DateTime? since,
          DateTime? sentBefore,
          DateTime? sentSince,
          int? pageSize}) =>
      MailSearch(
        query ?? this.query,
        queryType ?? this.queryType,
        messageType: messageType ?? this.messageType,
        before: before ?? this.before,
        since: since ?? this.since,
        sentBefore: sentBefore ?? this.sentBefore,
        sentSince: sentSince ?? this.sentSince,
        pageSize: pageSize ?? this.pageSize,
      );
}
