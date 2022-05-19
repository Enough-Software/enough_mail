import 'dart:convert';

import '../codecs/date_codec.dart';
import '../exception.dart';
import 'message_sequence.dart';

/// Which part of the message should be searched
enum SearchQueryType {
  /// Search for matching `Subject` header
  subject,

  /// Search for matching `From` header
  from,

  /// Search for matching `To` header
  to,

  /// Search for matches in the body of the message
  /// (a very resource intensive search, not every mail provider supports this)
  body,

  /// Search in all common headers (not every mail provider supports this)
  allTextHeaders,

  /// Search in either `FROM` or in `SUBJECT`.
  ///
  /// Specifically useful in cases where the mail provider
  /// does not support `allTextHeaders`
  fromOrSubject,

  /// Search in either `TO` or in `SUBJECT`.
  ///
  /// Specifically useful in cases where the mail provider
  /// does not support `allTextHeaders`
  toOrSubject,

  /// Search for matching `TO` or `FROM` headers
  fromOrTo,
}

/// Defines what kind of messages should be searched
enum SearchMessageType {
  /// any message
  all,

  /// any flagged messages
  flagged,

  /// any messages that are not flagged
  unflagged,

  /// any seen (read) messages
  seen,

  /// any messages that have not been seen
  unseen,

  /// any messages marked as deleted
  deleted,

  /// any messages that are not marked as deleted
  undeleted,

  /// any messages marked as draft
  draft,

  /// any messages not marked as draft
  undraft
}

/// Creates a new search query.
///
/// In IMAP any search query is combined with AND meaning all conditions
/// must be met by matching messages.
class SearchQueryBuilder {
  /// Creates a common search query.
  ///
  /// [query] contains the search text, define where to search
  /// with the [queryType].
  ///
  /// Optionally you can also define what kind of messages to search
  /// with the [messageType],
  ///
  /// the internal date since a message has been received with [since],
  ///
  /// the internal date before a message has been received with [before],
  ///
  /// the internal date since a message has been sent with [sentSince],
  ///
  /// the internal date before a message has been sent with [sentBefore],
  SearchQueryBuilder.from(
    String query,
    SearchQueryType queryType, {
    SearchMessageType? messageType,
    DateTime? since,
    DateTime? before,
    DateTime? sentSince,
    DateTime? sentBefore,
  }) {
    if (query.isNotEmpty) {
      if (_TextSearchTerm.containsNonAsciiCharacters(query)) {
        add(const SearchTermCharsetUf8());
      }
      switch (queryType) {
        case SearchQueryType.subject:
          add(SearchTermSubject(query));
          break;
        case SearchQueryType.from:
          add(SearchTermFrom(query));
          break;
        case SearchQueryType.to:
          add(SearchTermTo(query));
          break;
        case SearchQueryType.allTextHeaders:
          add(SearchTermText(query));
          break;
        case SearchQueryType.body:
          add(SearchTermBody(query));
          break;
        case SearchQueryType.fromOrSubject:
          add(SearchTermOr(SearchTermFrom(query), SearchTermSubject(query)));
          break;
        case SearchQueryType.toOrSubject:
          add(SearchTermOr(SearchTermTo(query), SearchTermSubject(query)));
          break;
        case SearchQueryType.fromOrTo:
          add(SearchTermOr(SearchTermFrom(query), SearchTermTo(query)));
          break;
      }
    }

    if (messageType != null) {
      switch (messageType) {
        case SearchMessageType.all:
          // ignore
          break;
        case SearchMessageType.flagged:
          add(const SearchTermFlagged());
          break;
        case SearchMessageType.unflagged:
          add(const SearchTermUnflagged());
          break;
        case SearchMessageType.seen:
          add(const SearchTermSeen());
          break;
        case SearchMessageType.unseen:
          add(const SearchTermUnseen());
          break;
        case SearchMessageType.deleted:
          add(const SearchTermDeleted());
          break;
        case SearchMessageType.undeleted:
          add(const SearchTermUndeleted());
          break;
        case SearchMessageType.draft:
          add(const SearchTermDraft());
          break;
        case SearchMessageType.undraft:
          add(const SearchTermUndraft());
          break;
      }
    }
    if (before != null) {
      add(SearchTermBefore(before));
    }
    if (since != null) {
      add(SearchTermSince(since));
    }
    if (sentBefore != null) {
      add(SearchTermSentBefore(sentBefore));
    }
    if (sentSince != null) {
      add(SearchTermSentSince(sentSince));
    }
  }

  /// The terms for this search query
  final searchTerms = <SearchTerm>[];

  /// Adds a new search term
  void add(SearchTerm term) {
    searchTerms.add(term);
  }

  /// Renders this search query to the given [buffer].
  void render(StringBuffer buffer) {
    var addSpace = false;
    for (final term in searchTerms) {
      if (addSpace) {
        buffer.write(' ');
      }
      buffer.write(term.term);
      addSpace = !term.term.endsWith('\n');
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    render(buffer);
    return buffer.toString();
  }
}

/// Base class for all search terms
abstract class SearchTerm {
  /// Creates a new search term
  const SearchTerm(this.term);

  /// The search
  final String term;

  /// Renders this term to the given [buffer].
  void render(StringBuffer buffer) {
    buffer.write(term);
  }
}

class _TextSearchTerm extends SearchTerm {
  _TextSearchTerm(String name, String? value) : super(merge(name, value));

  static String merge(String name, String? value) {
    if (value == null) {
      return name;
    }
    // check if there are UTF-8 characters:
    if (containsNonAsciiCharacters(value)) {
      final encoded = utf8.encode(value);
      return '$name {${encoded.length}}\n$value';
    }
    final escaped = value.replaceAll('"', r'\"');
    return '$name "$escaped"';
  }

  static bool containsNonAsciiCharacters(String value) {
    final runes = value.runes;
    for (final rune in runes) {
      if (rune >= 127) {
        return true;
      }
    }
    return false;
  }
}

class _DateSearchTerm extends SearchTerm {
  _DateSearchTerm(String name, DateTime value)
      : super('$name "${DateCodec.encodeSearchDate(value)}"');
}

/// Set the charset to UTF8
class SearchTermCharsetUf8 extends SearchTerm {
  /// Creates a new search term
  const SearchTermCharsetUf8() : super('CHARSET "UTF-8"');
}

/// Searches all messages
class SearchTermAll extends SearchTerm {
  /// Creates a new search term
  const SearchTermAll() : super('ALL');
}

/// Searches for answered/replied messages
class SearchTermAnswered extends SearchTerm {
  /// Creates a new search term
  const SearchTermAnswered() : super('ANSWERED');
}

/// Searches for messages with a BCC recipient that matches
class SearchTermBcc extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermBcc(String recipientPart) : super('BCC', recipientPart);
}

/// Searches for messages stored before the given date.
class SearchTermBefore extends _DateSearchTerm {
  /// Creates a new search term
  SearchTermBefore(DateTime dateTime) : super('BEFORE', dateTime);
}

/// Searches in the body of messages.
/// This is usually a long lasting operation.
class SearchTermBody extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermBody(String match) : super('BODY', match);
}

/// Searches for messages with a matching recipient on CC
class SearchTermCc extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermCc(String recipientPart) : super('CC', recipientPart);
}

/// Searches for deleted messages
class SearchTermDeleted extends SearchTerm {
  /// Creates a new search term
  const SearchTermDeleted() : super('DELETED');
}

/// Searches for draft messages
class SearchTermDraft extends SearchTerm {
  /// Creates a new search term
  const SearchTermDraft() : super('DRAFT');
}

/// Searches for flagged messages
class SearchTermFlagged extends SearchTerm {
  /// Creates a new search term
  const SearchTermFlagged() : super('FLAGGED');
}

/// Searches for messages where the sender matches the senderPart
class SearchTermFrom extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermFrom(String senderPart) : super('FROM', senderPart);
}

/// Searches for messages with the given header
class SearchTermHeader extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermHeader(String headerName, {String? headerValue})
      : super('HEADER $headerName', headerValue);
}

/// Searches for messages flagged with the given keyword
class SearchTermKeyword extends SearchTerm {
  /// Creates a new search term
  const SearchTermKeyword(String keyword) : super('KEYWORD $keyword');
}

/// Searches for messages that are bigger than the given size
class SearchTermLarger extends SearchTerm {
  /// Creates a new search term
  const SearchTermLarger(int bytes) : super('LARGER $bytes');
}

/// Searches for new messages
class SearchTermNew extends SearchTerm {
  /// Creates a new search term
  const SearchTermNew() : super('NEW');
}

/// Negates the given search term
class SearchTermNot extends SearchTerm {
  /// Creates a new search term
  SearchTermNot(SearchTerm term) : super('NOT ${term.term}');
}

/// Searches for old messages
class SearchTermOld extends SearchTerm {
  /// Creates a new search term
  const SearchTermOld() : super('OLD');
}

/// Searches for message stored at the given day
class SearchTermOn extends _DateSearchTerm {
  /// Creates a new search term
  SearchTermOn(DateTime dateTime) : super('ON', dateTime);
}

/// Combines two atomic search terms in an OR way
/// Note that you cannot nest an OR term into another OR term
class SearchTermOr extends SearchTerm {
  /// Creates a new search term
  SearchTermOr(SearchTerm term1, SearchTerm term2)
      : super(_merge(term1, term2));
  static String _merge(SearchTerm term1, SearchTerm term2) {
    if (term1 is SearchTermOr || term2 is SearchTermOr) {
      throw InvalidArgumentException('You cannot nest several OR search terms');
    }
    return 'OR ${term1.term} ${term2.term}';
  }
}

/// Searches for recent messages
class SearchTermRecent extends SearchTerm {
  /// Creates a new search term
  const SearchTermRecent() : super('RECENT');
}

/// Searches for seen / read messages
class SearchTermSeen extends SearchTerm {
  /// Creates a new search term
  const SearchTermSeen() : super('SEEN');
}

/// Searches for messages sent before the given date
class SearchTermSentBefore extends _DateSearchTerm {
  /// Creates a new search term
  SearchTermSentBefore(DateTime dateTime) : super('SENTBEFORE', dateTime);
}

/// Searches for message sent at the given day
class SearchTermSentOn extends _DateSearchTerm {
  /// Creates a new search term
  SearchTermSentOn(DateTime dateTime) : super('SENTON', dateTime);
}

/// Searches message sent after the given time
class SearchTermSentSince extends _DateSearchTerm {
  /// Creates a new search term
  SearchTermSentSince(DateTime dateTime) : super('SENTSINCE', dateTime);
}

/// Searches for messages stored after the given time
class SearchTermSince extends _DateSearchTerm {
  /// Creates a new search term
  SearchTermSince(DateTime dateTime) : super('SINCE', dateTime);
}

/// Searches messages with a size less than given
class SearchTermSmaller extends SearchTerm {
  /// Creates a new search term
  const SearchTermSmaller(int bytes) : super('SMALLER $bytes');
}

/// Searches for messages with a matching subject
class SearchTermSubject extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermSubject(String subjectPart) : super('SUBJECT', subjectPart);
}

/// Searches any text header
class SearchTermText extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermText(String textPart) : super('TEXT', textPart);
}

/// Searches for recipients
class SearchTermTo extends _TextSearchTerm {
  /// Creates a new search term
  SearchTermTo(String recipientPart) : super('TO', recipientPart);
}

/// Searches for the given UID messages
class UidSearchTerm extends SearchTerm {
  /// Creates a new search term
  UidSearchTerm(MessageSequence sequence) : super('UID $sequence');
}

/// Searches messages without the replied flag
class SearchTermUnanswered extends SearchTerm {
  /// Creates a new search term
  const SearchTermUnanswered() : super('UNANSWERED');
}

/// Searches messages that are not deleted
class SearchTermUndeleted extends SearchTerm {
  /// Creates a new search term
  const SearchTermUndeleted() : super('UNDELETED');
}

/// Searches for messages that carry no draft flag
class SearchTermUndraft extends SearchTerm {
  /// Creates a new search term
  const SearchTermUndraft() : super('UNDRAFT');
}

/// Search for not flagged messages
class SearchTermUnflagged extends SearchTerm {
  /// Creates a new search term
  const SearchTermUnflagged() : super('UNFLAGGED');
}

/// Searches for messages without the keyword
class SearchTermUnkeyword extends SearchTerm {
  /// Creates a new search term
  const SearchTermUnkeyword(String keyword) : super('UNKEYWORD $keyword');
}

/// Searches for unseen messages
class SearchTermUnseen extends SearchTerm {
  /// Creates a new search term
  const SearchTermUnseen() : super('UNSEEN');
}
