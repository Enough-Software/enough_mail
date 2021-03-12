import 'dart:collection';

import 'package:enough_mail/enough_mail.dart';

/// Defines a list of message IDs.
///
/// IDs can be either be based on sequence IDs or on UIDs.
class MessageSequence {
  /// True when this sequence is consisting of UIDs
  final bool isUidSequence;

  /// The length of this sequence - only valid when there is no range to last involved.
  int get length => toList().length;

  final List<int> _ids = <int>[];
  bool _isLastAdded = false;
  bool _isAllAdded = false;
  String? _text;

  bool _isNilSequence = false;
  bool get isNil => _isNilSequence;

  final int STAR = 0;
  final int RANGESTAR = -1;

  /// Creates a new message sequence.
  ///
  /// Optionally set [isUidSequence] to `true` in case this is a sequence based on UIDs. This defaults to `false`.
  MessageSequence({this.isUidSequence = false});

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
    var id = message.sequenceId;
    if (id == null) {
      throw StateError('no sequence ID found in message');
    }
    add(id);
  }

  /// Removes the sequence ID of the specified [message].
  void removeSequenceId(MimeMessage message) {
    var id = message.sequenceId;
    if (id == null) {
      throw StateError('no sequence ID found in message');
    }
    remove(id);
  }

  /// Adds the UID of the specified [message].
  void addUid(MimeMessage message) {
    var uid = message.uid;
    if (uid == null) {
      throw StateError('no UID found in message');
    }
    add(uid);
  }

  /// Remoces the UID of the specified [message].
  void removeUid(MimeMessage message) {
    var uid = message.uid;
    if (uid == null) {
      throw StateError('no UID found in message');
    }
    remove(uid);
  }

  /// Adds the specified ID
  void add(int id) {
    _ids.add(id);
    _text = null;
  }

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
    var wasEmpty = isEmpty();
    if (start < end) {
      _ids.addAll([for (int i = start; i <= end; i++) i]);
    } else {
      _ids.addAll([for (int i = end; i <= start; i++) i]);
    }
    _text = wasEmpty ? '$start:$end' : null;
  }

  /// Adds a range from the specified [start] ID towards to the last `*` element.
  void addRangeToLast(int start) {
    if (start == 0) {
      throw StateError('sequence ID must not be 0');
    }
    // start:*
    var wasEmpty = isEmpty();
    _isLastAdded = true;
    _ids.addAll([start, RANGESTAR]);
    _text = wasEmpty ? '$start:*' : null;
  }

  /// Adds the last element, which is alway `*`.
  void addLast() {
    // *
    var wasEmpty = isEmpty();
    _isLastAdded = true;
    _ids.add(STAR);
    _text = wasEmpty ? '*' : null;
  }

  /// Adds all messages
  ///
  /// This results into `1:*`.
  void addAll() {
    // 1:*
    var wasEmpty = isEmpty();
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

  /// Retrieves sequence containing the message IDs/UIDs from the page with the given [pageNumer] which starts at 1 and the given [pageSize].
  ///
  /// This pages start from the end of this sequence.
  /// When the page is 1 and the pageSize is equals or bigger than the `length` of this sequence, this sequence is returned.
  MessageSequence subsequenceFromPage(int pageNumber, int pageSize) {
    if (pageNumber == 1 && pageSize >= length) {
      return this;
    }
    final pageIndex = pageNumber - 1;
    final end = length - (pageIndex * pageSize);
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
  int elementAt(int index) {
    return _ids.elementAt(index);
  }

  /// Convenience method for getting the sequence for a single [id].
  ///
  /// Optionally specify the if the ID is a UID with [isUid], defaults to false.
  static MessageSequence fromId(int id, {bool isUid = false}) {
    final sequence = MessageSequence(isUidSequence: isUid);
    sequence.add(id);
    return sequence;
  }

  /// Convenience method to creating a sequence from a list of [ids].
  ///
  /// Optionally specify the if the ID is a UID with [isUid], defaults to false.
  static MessageSequence fromIds(List<int> ids, {bool isUid = false}) {
    final sequence = MessageSequence(isUidSequence: isUid);
    sequence.addList(ids);
    return sequence;
  }

  /// Convenience method for getting the sequence for a single [message].
  static MessageSequence fromSequenceId(MimeMessage message) {
    final sequence = MessageSequence();
    sequence.addSequenceId(message);
    return sequence;
  }

  /// Convenience method for getting the sequence for a single [message]'s UID.
  static MessageSequence fromUid(MimeMessage message) {
    final sequence = MessageSequence(isUidSequence: true);
    sequence.addUid(message);
    return sequence;
  }

  /// Convenience method for getting the sequence for a single [message]'s UID or sequence ID.
  static MessageSequence fromMessage(MimeMessage message) {
    bool isUid;
    int id;
    if (message.uid != null) {
      isUid = true;
      id = message.uid!;
    } else {
      isUid = false;
      id = message.sequenceId!;
    }
    final sequence = MessageSequence(isUidSequence: isUid);
    sequence.add(id);
    return sequence;
  }

  /// Convenience method for getting the sequence for the given [messages]'s UIDs or sequence IDs.
  static MessageSequence fromMessages(List<MimeMessage> messages) {
    if (messages.isEmpty) {
      throw StateError('Messages must not be empty or null: $messages');
    }
    final isUid = (messages.first.uid != null);
    final sequence = MessageSequence(isUidSequence: isUid);
    for (final message in messages) {
      sequence.add(isUid ? message.uid! : message.sequenceId!);
    }
    return sequence;
  }

  /// Convenience method for getting the sequence for a single range from [start] to [end] inclusive.
  static MessageSequence fromRange(int start, int end,
      {bool isUidSequence = false}) {
    final sequence = MessageSequence(isUidSequence: isUidSequence);
    sequence.addRange(start, end);
    return sequence;
  }

  /// Convenience method for getting the sequence for a single range from [start] to the last message inclusive.
  static MessageSequence fromRangeToLast(int start,
      {bool isUidSequence = false}) {
    final sequence = MessageSequence(isUidSequence: isUidSequence);
    sequence.addRangeToLast(start);
    return sequence;
  }

  /// Convenience method for getting the sequence for the last message.
  static MessageSequence fromLast() {
    final sequence = MessageSequence();
    sequence.addLast();
    return sequence;
  }

  /// Convenience method for getting the sequence for all messages.
  static MessageSequence fromAll() {
    final sequence = MessageSequence();
    sequence.addAll();
    return sequence;
  }

  /// Generates a sequence based on the specified inpput [text] like `1:10,21,73:79`.
  ///
  /// Set [isUidSequence] to `true` in case this sequence consists of UIDs.
  static MessageSequence parse(String text, {bool isUidSequence = false}) {
    final sequence = MessageSequence(isUidSequence: isUidSequence);
    var chunks = text.split(',');
    if (chunks[0] == 'NIL') {
      sequence._isNilSequence = true;
      sequence._text = null;
    } else {
      for (var chunk in chunks) {
        var id = int.tryParse(chunk);
        if (id != null) {
          sequence.add(id);
        } else if (chunk == '*') {
          sequence.addLast();
        } else if (chunk.endsWith(':*')) {
          var idText = chunk.substring(0, chunk.length - ':*'.length);
          var id = int.tryParse(idText);
          if (id != null) {
            sequence.addRangeToLast(id);
          } else {
            throw StateError('expect id in $idText for <$chunk> in $text');
          }
        } else {
          var colonIndex = chunk.indexOf(':');
          if (colonIndex == -1) {
            throw StateError('expect colon in  <$chunk> / $text');
          }
          var start = int.tryParse(chunk.substring(0, colonIndex));
          var end = int.tryParse(chunk.substring(colonIndex + 1));
          if (start == null || end == null) {
            throw StateError('expect range in  <$chunk> / $text');
          }
          sequence.addRange(start, end);
        }
      }
    }
    return sequence;
  }

  /// Checks if this sequence contains the last indicator in some form - '*'
  bool containsLast() {
    return _isLastAdded || _isAllAdded;
  }

  /// Lists all entries of this sequence.
  ///
  /// You must specify the number of existing messages with the [exists] parameter, in case this sequence contains the last element '*' in some form.
  /// Use the [containsLast()] method to determine if this sequence contains the last element '*'.
  List<int> toList([int? exists]) {
    if (exists == null && containsLast()) {
      throw StateError(
          'Unable to list sequence when * is part of the list and the \'exists\' parameter is not specified.');
    }
    if (_isNilSequence) {
      throw StateError('Unable to list non existent sequence.');
    }
    var idset = LinkedHashSet<int>.identity();
    if (_isAllAdded) {
      for (var i = 1; i <= exists!; i++) {
        idset.add(i);
      }
    } else {
      var index = 0;
      var zeroloc = _ids.indexOf(RANGESTAR, index);
      while (zeroloc > 0) {
        idset.addAll(_ids.sublist(index, zeroloc));
        // Using a for-loop because we must generate a sequence when reaching the "STAR" value
        idset.addAll([for (var x = idset.last + 1; x <= exists!; x++) x]);
        index = zeroloc + 1;
        zeroloc = _ids.indexOf(RANGESTAR, index);
      }
      if (index >= 0 && zeroloc == -1) {
        idset.addAll(_ids.sublist(index));
      }
    }
    if (idset.remove(STAR) && exists != null) {
      idset.add(exists);
    }
    return idset.toList();
  }

  /// Checks is this sequence has no elements
  bool isEmpty() {
    return !_isLastAdded && !_isAllAdded && _ids.isEmpty;
  }

  /// Checks is this sequence has at least one element
  bool isNotEmpty() {
    return _isLastAdded || _isAllAdded || _ids.isNotEmpty;
  }

  @override
  String toString() {
    if (_text != null) {
      return _text!;
    }
    var buffer = StringBuffer();
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
    if (isEmpty()) {
      throw StateError('no ID added to sequence');
    }
    if (_ids.length == 1) {
      buffer.write(_ids[0]);
    } else {
      var cache = 0;
      for (var i = 0; i < _ids.length; i++) {
        if (i == 0) {
          buffer.write(_ids[i] == STAR ? '*' : _ids[i]);
        } else if (_ids[i] == _ids[i - 1] + 1) {
          // Saves the current id of the range
          cache = _ids[i];
        } else {
          // Writes out the current range
          if (cache > 0) {
            buffer..write(':')..write(cache);
            cache = 0;
          }
          if (_ids[i] == RANGESTAR) {
            buffer..write(':')..write('*');
          } else {
            buffer..write(',')..write(_ids[i] == STAR ? '*' : _ids[i]);
          }
        }
      }
      // Writes out the range at the end of the sequence, if any
      if (cache > 0) {
        buffer..write(':')..write(cache);
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
      if (_ids.remove(STAR)) {
        _ids.add(STAR);
      }
      if (_ids.remove(RANGESTAR)) {
        _ids.add(RANGESTAR);
      }
    }
  }

  /// Iterates through the sequence
  Iterable<int> every() sync* {
    for (var id in _ids) {
      yield id;
    }
  }
}
