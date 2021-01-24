import 'package:enough_mail/codecs/date_codec.dart';
import 'package:enough_mail/enough_mail.dart';

/// Which part of the message should be searched
enum SearchQueryType {
  /// Search for matching `Subject` header
  subject,

  /// Search for matching `From` header
  from,

  /// Search for matching `To` header
  to,

  /// Search for matches in the body of the message (a very resource intensive search, not every mail provider supports this)
  body,

  /// Search in all common headers (not every mail provider supports this)
  allTextHeaders,

  /// Search in either FROM or in SUBJECT - specifically useful in cases where the mail provider does not support `allTextHeaders`
  fromOrSubject,

  /// Search in either TO or in SUBJECT - specifically useful in cases where the mail provider does not support `allTextHeaders`
  toOrSubject,
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
/// In IMAP any search query is combined with AND meaning all conditions must be met by matching messages.
class SearchQueryBuilder {
  final searchTerms = <SearchTerm>[];

  /// Adds a new search term
  void add(SearchTerm term) {
    searchTerms.add(term);
  }

  /// Helper to create a common search query.
  /// [query] contains the search text, define where to search with the [queryType].
  /// Optionally you can also define what kind of messages to search with the [messageType],
  /// the internal date since a message has been received with [since],
  /// the internal date before a message has been received with [before],
  /// the internal date since a message has been sent with [sentSince],
  /// the internal date before a message has been sent with [sentBefore],
  static SearchQueryBuilder from(String query, SearchQueryType queryType,
      {SearchMessageType messageType,
      DateTime since,
      DateTime before,
      DateTime sentSince,
      DateTime sentBefore}) {
    final builder = SearchQueryBuilder();
    if (query?.isNotEmpty ?? false) {
      switch (queryType) {
        case SearchQueryType.subject:
          builder.add(SearchTermSubject(query));
          break;
        case SearchQueryType.from:
          builder.add(SearchTermFrom(query));
          break;
        case SearchQueryType.to:
          builder.add(SearchTermTo(query));
          break;
        case SearchQueryType.allTextHeaders:
          builder.add(SearchTermText(query));
          break;
        case SearchQueryType.body:
          builder.add(SearchTermBody(query));
          break;
        case SearchQueryType.fromOrSubject:
          builder.add(
              SearchTermOr(SearchTermFrom(query), SearchTermSubject(query)));
          break;
        case SearchQueryType.toOrSubject:
          builder
              .add(SearchTermOr(SearchTermTo(query), SearchTermSubject(query)));
          break;
      }
    }

    if (messageType != null) {
      switch (messageType) {
        case SearchMessageType.all:
          // ignore
          break;
        case SearchMessageType.flagged:
          builder.add(SearchTermFlagged());
          break;
        case SearchMessageType.unflagged:
          builder.add(SearchTermUnflagged());
          break;
        case SearchMessageType.seen:
          builder.add(SearchTermSeen());
          break;
        case SearchMessageType.unseen:
          builder.add(SearchTermUnseen());
          break;
        case SearchMessageType.deleted:
          builder.add(SearchTermDeleted());
          break;
        case SearchMessageType.undeleted:
          builder.add(SearchTermUndeleted());
          break;
        case SearchMessageType.draft:
          builder.add(SearchTermDraft());
          break;
        case SearchMessageType.undraft:
          builder.add(SearchTermUndraft());
          break;
      }
    }
    if (before != null) {
      builder.add(SearchTermBefore(before));
    }
    if (since != null) {
      builder.add(SearchTermSince(since));
    }
    if (sentBefore != null) {
      builder.add(SearchTermSentBefore(sentBefore));
    }
    if (sentSince != null) {
      builder.add(SearchTermSentSince(sentSince));
    }
    return builder;
  }

  void render(StringBuffer buffer) {
    var addSpace = false;
    for (final term in searchTerms) {
      if (addSpace) {
        buffer.write(' ');
      }
      buffer.write(term.term);
      addSpace = true;
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    render(buffer);
    return buffer.toString();
  }
}

abstract class SearchTerm {
  final String term;
  const SearchTerm(this.term);

  void render(StringBuffer buffer) {
    buffer.write(term);
  }
}

class _TextSearchTerm extends SearchTerm {
  _TextSearchTerm(String name, String value) : super(merge(name, value));

  static String merge(String name, String value) {
    if (value == null) {
      return name;
    }
    final escaped = value.replaceAll('"', r'\"');
    return (escaped.contains(' ')) ? '$name "$escaped"' : '$name $escaped';
  }
}

class _DateSearchTerm extends SearchTerm {
  _DateSearchTerm(String name, DateTime value)
      : super('$name "${DateCodec.encodeSearchDate(value)}"');
}

class SearchTermAll extends SearchTerm {
  const SearchTermAll() : super('ALL');
}

class SearchTermAnswered extends SearchTerm {
  const SearchTermAnswered() : super('ANSWERED');
}

class SearchTermBcc extends _TextSearchTerm {
  SearchTermBcc(String recipientPart) : super('BCC', recipientPart);
}

class SearchTermBefore extends _DateSearchTerm {
  SearchTermBefore(DateTime dateTime) : super('BEFORE', dateTime);
}

class SearchTermBody extends _TextSearchTerm {
  SearchTermBody(String match) : super('BODY', match);
}

class SearchTermCc extends _TextSearchTerm {
  SearchTermCc(String recipientPart) : super('CC', recipientPart);
}

class SearchTermDeleted extends SearchTerm {
  const SearchTermDeleted() : super('DELETED');
}

class SearchTermDraft extends SearchTerm {
  const SearchTermDraft() : super('DRAFT');
}

class SearchTermFlagged extends SearchTerm {
  const SearchTermFlagged() : super('FLAGGED');
}

class SearchTermFrom extends _TextSearchTerm {
  SearchTermFrom(String senderPart) : super('FROM', senderPart);
}

class SearchTermHeader extends _TextSearchTerm {
  SearchTermHeader(String headerName, {String headerValue})
      : super('HEADER $headerName', headerValue);
}

class SearchTermKeyword extends SearchTerm {
  const SearchTermKeyword(String keyword) : super('KEYWORD $keyword');
}

class SearchTermLarger extends SearchTerm {
  const SearchTermLarger(int bytes) : super('LARGER $bytes');
}

class SearchTermNew extends SearchTerm {
  const SearchTermNew() : super('NEW');
}

class SearchTermNot extends SearchTerm {
  SearchTermNot(SearchTerm term) : super('NOT ${term.term}');
}

class SearchTermOld extends SearchTerm {
  const SearchTermOld() : super('OLD');
}

class SearchTermOn extends _DateSearchTerm {
  SearchTermOn(DateTime dateTime) : super('ON', dateTime);
}

/// Combines two atomic search terms in an OR way
/// Note that you cannot nest an OR term into another OR term
class SearchTermOr extends SearchTerm {
  SearchTermOr(SearchTerm term1, SearchTerm term2)
      : super(_merge(term1, term2));
  static String _merge(SearchTerm term1, SearchTerm term2) {
    if (term1 is SearchTermOr || term2 is SearchTermOr) {
      throw StateError('You cannot nest several OR search terms');
    }
    return 'OR ${term1.term} ${term2.term}';
  }
}

class SearchTermRecent extends SearchTerm {
  const SearchTermRecent() : super('RECENT');
}

class SearchTermSeen extends SearchTerm {
  const SearchTermSeen() : super('SEEN');
}

class SearchTermSentBefore extends _DateSearchTerm {
  SearchTermSentBefore(DateTime dateTime) : super('SENTBEFORE', dateTime);
}

class SearchTermSentOn extends _DateSearchTerm {
  SearchTermSentOn(DateTime dateTime) : super('SENTON', dateTime);
}

class SearchTermSentSince extends _DateSearchTerm {
  SearchTermSentSince(DateTime dateTime) : super('SENTSINCE', dateTime);
}

class SearchTermSince extends _DateSearchTerm {
  SearchTermSince(DateTime dateTime) : super('SINCE', dateTime);
}

class SearchTermSmaller extends SearchTerm {
  const SearchTermSmaller(int bytes) : super('SMALLER $bytes');
}

class SearchTermSubject extends _TextSearchTerm {
  SearchTermSubject(String subjectPart) : super('SUBJECT', subjectPart);
}

class SearchTermText extends _TextSearchTerm {
  SearchTermText(String textPart) : super('TEXT', textPart);
}

class SearchTermTo extends _TextSearchTerm {
  SearchTermTo(String recipientPart) : super('TO', recipientPart);
}

class UidSearchTerm extends SearchTerm {
  UidSearchTerm(MessageSequence sequence) : super('UID $sequence');
}

class SearchTermUnanswered extends SearchTerm {
  const SearchTermUnanswered() : super('UNANSWERED');
}

class SearchTermUndeleted extends SearchTerm {
  const SearchTermUndeleted() : super('UNDELETED');
}

class SearchTermUndraft extends SearchTerm {
  const SearchTermUndraft() : super('UNDRAFT');
}

class SearchTermUnflagged extends SearchTerm {
  const SearchTermUnflagged() : super('UNFLAGGED');
}

class SearchTermUnkeyword extends SearchTerm {
  const SearchTermUnkeyword(String keyword) : super('UNKEYWORD $keyword');
}

class SearchTermUnseen extends SearchTerm {
  const SearchTermUnseen() : super('UNSEEN');
}
