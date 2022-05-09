import 'dart:collection';

import '../exception.dart';
import '../mime_message.dart';

/// Defines a list of message IDs.
///
/// IDs can be either be based on sequence IDs or on UIDs.
class MessageSequence {
  /// Creates a new message sequence.
  ///
  /// Optionally set [isUidSequence] to `true` in case this is a sequence
  /// based on UIDs. This defaults to `false`.
  MessageSequence({this.isUidSequence = false});

  /// Convenience method for getting the sequence for a single [id].
  ///
  /// Optionally specify the if the ID is a UID with [isUid], defaults to false.
  MessageSequence.fromId(int id, {bool isUid = false}) : isUidSequence = isUid {
    add(id);
  }

  /// Convenience method to creating a sequence from a list of [ids].
  ///
  /// Optionally specify the if the ID is a UID with [isUid], defaults to false.
  MessageSequence.fromIds(List<int> ids, {bool isUid = false})
      : isUidSequence = isUid {
    addList(ids);
  }

  /// Convenience method for getting the sequence for a single [message].
  MessageSequence.fromSequenceId(MimeMessage message) : isUidSequence = false {
    addSequenceId(message);
  }

  /// Convenience method for getting the sequence for a single [message]'s UID.
  MessageSequence.fromUid(MimeMessage message) : isUidSequence = true {
    addUid(message);
  }

  /// Convenience method for getting the sequence for a single [message]'s
  /// UID or sequence ID.
  MessageSequence.fromMessage(MimeMessage message)
      : isUidSequence = message.uid != null {
    if (isUidSequence) {
      addUid(message);
    } else {
      addSequenceId(message);
    }
  }

  /// Convenience method for getting the sequence for the given [messages]'s
  /// UIDs or sequence IDs.
  MessageSequence.fromMessages(List<MimeMessage> messages)
      : isUidSequence = messages.isNotEmpty && messages.first.uid != null {
    if (isUidSequence) {
      messages.forEach(addUid);
    } else {
      messages.forEach(addSequenceId);
    }
  }

  /// Convenience method for getting the sequence for a single range from
  /// [start] to [end] inclusive.
  MessageSequence.fromRange(int start, int end, {this.isUidSequence = false}) {
    addRange(start, end);
  }

  /// Convenience method for getting the sequence for a single range from
  /// [start] to the last message inclusive.
  ///
  /// Note that the last message will always be returned, even when
  /// the sequence ID / UID of the last message is smaller than [start].
  MessageSequence.fromRangeToLast(int start, {this.isUidSequence = false}) {
    addRangeToLast(start);
  }

  /// Convenience method for getting the sequence for the last message.
  MessageSequence.fromLast() : isUidSequence = false {
    addLast();
  }

  /// Convenience method for getting the sequence for all messages.
  MessageSequence.fromAll() : isUidSequence = false {
    addAll();
  }

  /// Generates a sequence based on the specified input [text]
  /// like `1:10,21,73:79`.
  ///
  /// Set [isUidSequence] to `true` in case this sequence consists of UIDs.
  MessageSequence.parse(String text, {this.isUidSequence = false}) {
    final chunks = text.split(',');
    if (chunks[0] == 'NIL') {
      _isNilSequence = true;
      _text = null;
    } else {
      for (final chunk in chunks) {
        final id = int.tryParse(chunk);
        if (id != null) {
          add(id);
        } else if (chunk == '*') {
          addLast();
        } else if (chunk.endsWith(':*')) {
          final idText = chunk.substring(0, chunk.length - ':*'.length);
          final id = int.tryParse(idText);
          if (id != null) {
            addRangeToLast(id);
          } else {
            throw InvalidArgumentException(
                'expect id in $idText for <$chunk> in $text');
          }
        } else {
          final colonIndex = chunk.indexOf(':');
          if (colonIndex == -1) {
            throw InvalidArgumentException('expect colon in  <$chunk> / $text');
          }
          final start = int.tryParse(chunk.substring(0, colonIndex));
          final end = int.tryParse(chunk.substring(colonIndex + 1));
          if (start == null || end == null) {
            throw InvalidArgumentException('expect range in  <$chunk> / $text');
          }
          addRange(start, end);
        }
      }
    }
  }

  /// Convenience method for getting the sequence for a range defined by the
  /// [page] starting with `1`, the [pageSize] and the number
  /// of messages [messagesExist].
  factory MessageSequence.fromPage(int page, int pageSize, int messagesExist,
      {bool isUidSequence = false}) {
    final rangeStart = messagesExist - page * pageSize + 1;

    if (page == 1) {
      // ensure that also get any new messages:
      return MessageSequence.fromRangeToLast(rangeStart < 1 ? 1 : rangeStart,
          isUidSequence: isUidSequence);
    }
    final rangeEnd = rangeStart + pageSize - 1;
    return MessageSequence.fromRange(rangeStart < 1 ? 1 : rangeStart, rangeEnd,
        isUidSequence: isUidSequence);
  }

  /// True when this sequence is consisting of UIDs
  final bool isUidSequence;

  /// The length of this sequence.
  ///
  /// Only valid when there is no range to last involved.
  int get length => toList().length;

  /// Checks is this sequence has at no elements.
  bool get isEmpty => !_isLastAdded && !_isAllAdded && _ids.isEmpty;

  /// Checks is this sequence has at least one element.
  bool get isNotEmpty => _isLastAdded || _isAllAdded || _ids.isNotEmpty;

  final List<int> _ids = <int>[];
  bool _isLastAdded = false;
  bool _isAllAdded = false;
  String? _text;

  bool _isNilSequence = false;

  /// Is this a null sequence?
  bool get isNil => _isNilSequence;

  static const int _elementStar = 0;
  static const int _elementRangeStar = -1;

  /// Adds the UID or sequence ID of the [message] to this sequence.
  void addMessage(MimeMessage message) {
    if (isUidSequence) {
      add(message.uid!);
    } else {
      add(message.sequenceId!);
    }
  }

  /// Removes the UID or sequence ID of the [message] to this sequence.
  void removeMessage(MimeMessage message) {
    if (isUidSequence) {
      remove(message.uid!);
    } else {
      remove(message.sequenceId!);
    }
  }

  /// Adds the sequence ID of the specified [message].
  void addSequenceId(MimeMessage message) {
    final id = message.sequenceId;
    if (id == null) {
      throw InvalidArgumentException('no sequence ID found in message');
    }
    add(id);
  }

  /// Removes the sequence ID of the specified [message].
  void removeSequenceId(MimeMessage message) {
    final id = message.sequenceId;
    if (id == null) {
      throw InvalidArgumentException('no sequence ID found in message');
    }
    remove(id);
  }

  /// Adds the UID of the specified [message].
  void addUid(MimeMessage message) {
    final uid = message.uid;
    if (uid == null) {
      throw InvalidArgumentException('no UID found in message');
    }
    add(uid);
  }

  /// Removes the UID of the specified [message].
  void removeUid(MimeMessage message) {
    final uid = message.uid;
    if (uid == null) {
      throw InvalidArgumentException('no UID found in message');
    }
    remove(uid);
  }

  /// Adds the specified [id]
  void add(int id) {
    _ids.add(id);
    _text = null;
  }

  /// Removes the given [id]
  void remove(int id) {
    _ids.remove(id);
    _text = null;
  }

  /// Adds all messages between [start] and [end] inclusive.
  void addRange(int start, int end) {
    // start:end
    if (start == end) {
      add(start);
      return;
    }
    final wasEmpty = isEmpty;
    if (start < end) {
      _ids.addAll([for (int i = start; i <= end; i++) i]);
    } else {
      _ids.addAll([for (int i = end; i <= start; i++) i]);
    }
    _text = wasEmpty ? '$start:$end' : null;
  }

  /// Adds a range from the specified [start] ID to
  /// to the last `*` element.
  void addRangeToLast(int start) {
    if (start == 0) {
      throw InvalidArgumentException('sequence ID must not be 0');
    }
    // start:*
    final wasEmpty = isEmpty;
    _isLastAdded = true;
    _ids.addAll([start, _elementRangeStar]);
    _text = wasEmpty ? '$start:*' : null;
  }

  /// Adds the last element, which is alway `*`.
  void addLast() {
    // *
    final wasEmpty = isEmpty;
    _isLastAdded = true;
    _ids.add(_elementStar);
    _text = wasEmpty ? '*' : null;
  }

  /// Adds all messages
  ///
  /// This results into `1:*`.
  void addAll() {
    // 1:*
    final wasEmpty = isEmpty;
    _isAllAdded = true;
    if (wasEmpty) {
      _text = '1:*';
    } else {
      _text = null;
    }
  }

  /// Adds a user defined sequence of IDs
  void addList(List<int> ids) {
    _ids.addAll(ids);
    _text = null;
  }

  /// Creates a new sequence containing the message IDs/UIDs between [start] (inclusive) and [end] (exclusive)
  MessageSequence subsequence(int start, [int? end]) {
    final sublist = _ids.sublist(start, end);
    final subsequence = MessageSequence(isUidSequence: isUidSequence);
    subsequence._ids.addAll(sublist);
    return subsequence;
  }

  /// Retrieves sequence containing the message IDs/UIDs from the page
  /// with the given [pageNumber] which starts at 1 and the given [pageSize].
  ///
  /// This pages start from the end of this sequence,
  /// optionally skipping the first [skip] entries.
  /// When the [pageNumber] is 1 and the [pageSize] is equals or bigger
  /// than the [length] of this sequence, this sequence is returned.
  MessageSequence subsequenceFromPage(int pageNumber, int pageSize,
      {int skip = 0}) {
    if (pageNumber == 1 && pageSize >= length) {
      return this;
    }
    final pageIndex = pageNumber - 1;
    final end = length - skip - (pageIndex * pageSize);
    if (end <= 0) {
      return MessageSequence();
    }
    var start = end - pageSize;
    if (start < 0) {
      start = 0;
    }
    return subsequence(start, end);
  }

  /// Retrieves the ID at the specified zero-based [index].
  int elementAt(int index) => _ids.elementAt(index);

  /// Retrieves the ID at the specified zero-based [index].
  int operator [](int index) => _ids.elementAt(index);

  /// Checks if this sequence contains the last indicator in some form - '*'
  bool containsLast() => _isLastAdded || _isAllAdded;

  /// Lists all entries of this sequence.
  ///
  /// You must specify the number of existing messages with the [exists]
  /// parameter, in case this sequence contains the last element '*'
  /// in some form.
  /// Use the [containsLast] method to determine if this sequence contains
  /// the last element '*'.
  List<int> toList([int? exists]) {
    if (exists == null && containsLast()) {
      throw InvalidArgumentException(
          'Unable to list sequence when * is part of the list and the '
          '\'exists\' parameter is not specified.');
    }
    if (_isNilSequence) {
      throw InvalidArgumentException('Unable to list non existent sequence.');
    }
    final idSet = LinkedHashSet<int>.identity();
    if (_isAllAdded) {
      for (var i = 1; i <= exists!; i++) {
        idSet.add(i);
      }
    } else {
      var index = 0;
      var zeroLoc = _ids.indexOf(_elementRangeStar, index);
      while (zeroLoc > 0) {
        idSet
          ..addAll(_ids.sublist(index, zeroLoc))
          // Using a for-loop because we must generate a sequence when
          //reaching the `STAR` value
          ..addAll([for (var x = idSet.last + 1; x <= exists!; x++) x]);
        index = zeroLoc + 1;
        zeroLoc = _ids.indexOf(_elementRangeStar, index);
      }
      if (index >= 0 && zeroLoc == -1) {
        idSet.addAll(_ids.sublist(index));
      }
    }
    if (idSet.remove(_elementStar) && exists != null) {
      idSet.add(exists);
    }
    return idSet.toList();
  }

  @override
  String toString() {
    if (_text != null) {
      return _text!;
    }
    final buffer = StringBuffer();
    render(buffer);
    return buffer.toString();
  }

  /// Renders this message sequence into the specified StringBuffer [buffer].
  void render(StringBuffer buffer) {
    if (_isNilSequence) {
      buffer.write('NIL');
      return;
    }
    if (_text != null) {
      buffer.write(_text);
      return;
    }
    if (isEmpty) {
      throw InvalidArgumentException('no ID added to sequence');
    }
    if (_ids.length == 1) {
      buffer.write(_ids[0]);
    } else {
      var cache = 0;
      for (var i = 0; i < _ids.length; i++) {
        if (i == 0) {
          buffer.write(_ids[i] == _elementStar ? '*' : _ids[i]);
        } else if (_ids[i] == _ids[i - 1] + 1) {
          // Saves the current id of the range
          cache = _ids[i];
        } else {
          // Writes out the current range
          if (cache > 0) {
            buffer
              ..write(':')
              ..write(cache);
            cache = 0;
          }
          if (_ids[i] == _elementRangeStar) {
            buffer
              ..write(':')
              ..write('*');
          } else {
            buffer
              ..write(',')
              ..write(_ids[i] == _elementStar ? '*' : _ids[i]);
          }
        }
      }
      // Writes out the range at the end of the sequence, if any
      if (cache > 0) {
        buffer
          ..write(':')
          ..write(cache);
        cache = 0;
      }
    }
    if (_isAllAdded) {
      if (buffer.length > 0) {
        buffer.write(',');
      }
      buffer.write('1:*');
    }
  }

  /// Sorts the sequence set.
  ///
  /// Use when the request assumes an ordered sequence of IDs or UIDs
  void sort() {
    _ids.sort();
    // Moves the `*` placeholder to the bottom
    if (_isLastAdded) {
      if (_ids.remove(_elementStar)) {
        _ids.add(_elementStar);
      }
      if (_ids.remove(_elementRangeStar)) {
        _ids.add(_elementRangeStar);
      }
    }
  }

  /// Iterates through the sequence
  Iterable<int> every() sync* {
    for (final id in _ids) {
      yield id;
    }
  }
}

/// Selection mode for retrieving a `MessageSequence` from a nested
/// `SequenceNode` structure.
enum SequenceNodeSelectionMode {
  /// All message IDs are retrieved
  all,

  /// Only the first / root / oldest leaf of each nested 'thread' is retrieved
  firstLeaf,

  /// Only the last  / newest leaf of each nested 'thread'  is retrieved
  lastLeaf
}

/// A message sequence to handle nested IDs like in the IMAP THREAD extension.
class SequenceNode {
  /// Creates a sequence node with the given [id] and `true` in [isUid]
  /// if this belongs to a UID sequence.
  SequenceNode(this.id, {required this.isUid});

  /// Creates a root node with `true` in [isUid] if this belongs to a
  /// UID sequence.
  ///
  /// Root nodes can occur anywhere in a nested sequence node unless it has
  /// been flattened.
  ///
  /// Compare [flatten]
  SequenceNode.root({required this.isUid}) : id = -1;

  /// Children of this node
  final children = <SequenceNode>[];

  /// The ID, the root node has an ID of -1
  final int id;

  /// Checks if this node has an ID, otherwise it is a root node
  bool get hasId => id != -1;

  /// Defines if this is a UID (when `true`) or a sequenceId (when `false`).
  final bool isUid;

  /// Checks if this node has no children
  bool get isEmpty => children.isEmpty;

  /// Checks if this node has children
  bool get isNotEmpty => children.isNotEmpty;

  /// Retrieves the number of children of this node
  int get length => children.length;

  /// Retrieves the ID of the latest message node
  int get latestId => isEmpty ? id : children[length - 1].latestId;

  /// Adds a child with the given ID.
  SequenceNode addChild(int childId) {
    final child = SequenceNode(childId, isUid: isUid);
    children.add(child);
    return child;
  }

  /// Renders this node into the given [buffer].
  void render(StringBuffer buffer) {
    if (id != -1) {
      buffer.write(id);
    }
    if (isNotEmpty) {
      buffer.write('(');
      var addSpace = false;
      for (final child in children) {
        if (addSpace) {
          buffer.write(' ');
        }
        child.render(buffer);
        addSpace = true;
      }
      buffer.write(')');
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer()..write('SequenceNode ');
    if (isUid) {
      buffer.write('(UID) ');
    }
    if (isEmpty) {
      buffer.write('<empty>');
    } else {
      render(buffer);
    }
    return buffer.toString();
  }

  /// Retrieves the child node at the given index
  SequenceNode operator [](int index) => children[index];

  /// Flattens the structure with the given [depth] so that only the returned
  /// node is actually a root node.
  ///
  /// When the [depth] is `1`, then only the direct children are allowed,
  /// if it has higher, there can be additional
  /// descendants. [depth] must not be lower than `1`. [depth] defaults to `2`.
  SequenceNode flatten({int depth = 2}) {
    assert(depth >= 1, 'depth must be at least 1 ($depth is invalid)');
    final root = SequenceNode.root(isUid: isUid);
    _flatten(depth, root);
    return root;
  }

  void _flatten(int depth, SequenceNode parent) {
    if (hasId) {
      // this is a leaf
      parent.addChild(id);
    }
    if (depth == 1) {
      for (final child in children) {
        if (child.hasId) {
          parent.children.add(child);
        } else {
          child._flatten(depth, parent);
        }
      }
    } else {
      for (final child in children) {
        final parentChild = SequenceNode.root(isUid: isUid);
        parent.children.add(parentChild);
        child._flatten(depth - 1, parentChild);
      }
    }
  }

  /// Converts this node to a message sequence in the specified [mode].
  ///
  /// The [mode] defaults to all message IDs.
  MessageSequence toMessageSequence(
      {SequenceNodeSelectionMode mode = SequenceNodeSelectionMode.all}) {
    final sequence = MessageSequence(isUidSequence: isUid);
    _addToSequence(sequence, mode, 0);
    return sequence;
  }

  void _addToSequence(
      MessageSequence sequence, SequenceNodeSelectionMode mode, int depth) {
    if (mode == SequenceNodeSelectionMode.all || depth == 0) {
      if (hasId) {
        sequence.add(id);
      }
      for (final child in children) {
        child._addToSequence(sequence, mode, depth + 1);
      }
    } else if (mode == SequenceNodeSelectionMode.firstLeaf) {
      if (hasId) {
        sequence.add(id);
      } else if (length > 0) {
        children[0]._addToSequence(sequence, mode, depth + 1);
      }
    } else {
      // mode is last leaf:
      if (length == 0 && hasId) {
        sequence.add(id);
      } else if (length > 0) {
        children[length - 1]._addToSequence(sequence, mode, depth + 1);
      }
    }
  }
}

/// A paginated list of message IDs
class PagedMessageSequence {
  /// Creates a new paged sequence from the given [sequence]
  /// with the optional [pageSize].
  PagedMessageSequence(this.sequence, {this.pageSize = 30})
      : _messageSequenceIds = sequence.toList();

  /// Creates a new empty paged sequence with the optional [pageSize].
  PagedMessageSequence.empty({int pageSize = 30})
      : this(MessageSequence(), pageSize: pageSize);

  /// The original sequence
  final MessageSequence sequence;
  final List<int> _messageSequenceIds;

  /// The page size
  final int pageSize;

  /// Determines if this is a UID sequence
  bool get isUidSequence => sequence.isUidSequence;
  int _currentPage = 0;
  int _addedIds = 0;

  /// Retrieves the 0-based index of the current page
  int get currentPageIndex => _currentPage;

  /// Retrieves the length of the sequence
  int get length => _messageSequenceIds.length;

  /// Checks if this paged list has a next page
  bool get hasNext => _currentPage * pageSize < length;

  /// Retrieves the ID at the given [index]
  int operator [](int index) => _messageSequenceIds[index];

  /// Retrieves the sequence for the current page.
  ///
  /// You have to call `next()` before you can access the first page.
  MessageSequence getCurrentPage() {
    assert(_currentPage > 0,
        'You have to call next() before you can access the first page.');
    return sequence.subsequenceFromPage(_currentPage, pageSize,
        skip: _addedIds);
  }

  /// Advances this sequence to the next page and then returns
  /// `getCurrentPage()`.
  ///
  /// You have to check the `hasNext` property first before you can call
  /// `next()`.
  MessageSequence next() {
    assert(hasNext,
        'This paged sequence has no next page. Check hasNext property.');
    _currentPage++;
    return getCurrentPage();
  }

  /// Adds the given [id] to this paged sequence
  void add(int id) {
    _addedIds++;
    sequence.add(id);
    _messageSequenceIds.add(id);
  }

  /// Inserts the given [id] to this paged sequence
  void insert(int id) {
    _addedIds++;
    sequence.add(id);
    _messageSequenceIds.insert(0, id);
  }

  /// Removes the given [id] from this paged sequence
  void remove(int id) {
    _messageSequenceIds.remove(id);
    sequence.remove(id);
  }

  /// Retrieves the page index for the given ID
  int pageIndexOf(int index) => index ~/ pageSize;

  /// Retrieves the sequence for the specified page index
  MessageSequence getSequence(int pageIndex) =>
      sequence.subsequenceFromPage(pageIndex + 1, pageSize, skip: _addedIds);
}

/// Allows to get a sequence for a list of [MimeMessage]s easily
extension SequenceExtension on List<MimeMessage> {
  /// Retrieves a message sequence from this list of [MimeMessage]s
  MessageSequence toSequence() => MessageSequence.fromMessages(this);
}
