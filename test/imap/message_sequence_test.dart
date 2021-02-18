import 'package:test/test.dart';
import 'package:enough_mail/imap/message_sequence.dart';

void main() {
  group('Add ids', () {
    test('1 id', () {
      var sequence = MessageSequence();
      var ids = [1];
      for (var id in ids) {
        sequence.add(id);
      }
      expect(sequence.toString(), '1');
    });
    test('3 separate ids', () {
      var sequence = MessageSequence();
      var ids = [1, 999, 7];
      for (var id in ids) {
        sequence.add(id);
      }
      expect(sequence.toString(), '1,999,7');
    });
    test('4 ids with range', () {
      var sequence = MessageSequence();
      var ids = [1, 7, 5, 6];
      for (var id in ids) {
        sequence.add(id);
      }
      expect(sequence.toString(), '1,7,5:6');
    });

    test('9 ids with range', () {
      var sequence = MessageSequence();
      var ids = [1, 7, 5, 6, 9, 12, 11, 10, 2];
      for (var id in ids) {
        sequence.add(id);
      }
      expect(sequence.toString(), '1,7,5:6,9,12,11,10,2');
    });
    test('9 ids with range but last', () {
      var sequence = MessageSequence();
      var ids = [1, 7, 5, 6, 9, 13, 11, 10, 2];
      for (var id in ids) {
        sequence.add(id);
      }
      expect(sequence.toString(), '1,7,5:6,9,13,11,10,2');
    });
  });

  group('Add ids sorted', () {
    test('1 id', () {
      var sequence = MessageSequence();
      var ids = [1];
      for (var id in ids) {
        sequence.add(id);
      }
      expect(sequence.toString(), '1');
    });
    test('3 separate ids', () {
      var sequence = MessageSequence();
      var ids = [1, 999, 7];
      for (var id in ids) {
        sequence.add(id);
      }
      expect((sequence..sorted()).toString(), '1,7,999');
    });
    test('4 ids with range', () {
      var sequence = MessageSequence();
      var ids = [1, 7, 5, 6];
      for (var id in ids) {
        sequence.add(id);
      }
      expect((sequence..sorted()).toString(), '1,5:7');
    });

    test('9 ids with range', () {
      var sequence = MessageSequence();
      var ids = [1, 7, 5, 6, 9, 12, 11, 10, 2];
      for (var id in ids) {
        sequence.add(id);
      }
      expect((sequence..sorted()).toString(), '1:2,5:7,9:12');
    });
    test('9 ids with range but last', () {
      var sequence = MessageSequence();
      var ids = [1, 7, 5, 6, 9, 13, 11, 10, 2];
      for (var id in ids) {
        sequence.add(id);
      }
      expect((sequence..sorted()).toString(), '1:2,5:7,9:11,13');
    });
  });

  group('Add Last', () {
    test('Only last', () {
      var sequence = MessageSequence();
      var ids = [];
      for (var id in ids) {
        sequence.add(id);
      }
      sequence.addLast();
      expect(sequence.toString(), '*');
    });
    test('id + last', () {
      var sequence = MessageSequence();
      var ids = [232];
      for (var id in ids) {
        sequence.add(id);
      }
      sequence.addLast();
      expect(sequence.toString(), '232,*');
    });
  });

  group('Add ranges', () {
    test('1 range', () {
      var sequence = MessageSequence();
      sequence.addRange(12, 277);
      expect(sequence.toString(), '12:277');
    });
    test('2 ranges', () {
      var sequence = MessageSequence();
      sequence.addRange(12, 277);
      sequence.addRange(1, 7);
      expect(sequence.toString(), '12:277,1:7');
    });
    test('2 ranges with id and last', () {
      var sequence = MessageSequence();
      var ids = [2312];
      for (var id in ids) {
        sequence.add(id);
      }
      sequence.addRange(12, 277);
      sequence.addRange(1, 7);
      sequence.addLast();
      expect(sequence.toString(), '2312,12:277,1:7,*');
    });
  });

  group('Add range-to-last', () {
    test('1 range to last', () {
      var sequence = MessageSequence();
      sequence.addRangeToLast(12);
      expect(sequence.toString(), '12:*');
    });
    test('1 range to end, 1 normal range', () {
      var sequence = MessageSequence();
      sequence.addRangeToLast(12);
      sequence.addRange(1, 7);
      expect(sequence.toString(), '12:*,1:7');
    });
    test('mixed ranges', () {
      var sequence = MessageSequence();
      var ids = [2312, 2322];
      for (var id in ids) {
        sequence.add(id);
      }
      sequence.addRange(12, 277);
      sequence.addRangeToLast(23290);
      expect(sequence.toString(), '2312,2322,12:277,23290:*');
    });
  });

  group('Add all', () {
    test('Just all', () {
      var sequence = MessageSequence();
      sequence.addAll();
      expect(sequence.toString(), '1:*');
    });
    test('all + 1 id', () {
      var sequence = MessageSequence();
      sequence.add(12);
      sequence.addAll();
      expect(sequence.toString(), '12,1:*');
    });
  });

  group('Convenience methods', () {
    test('from all', () {
      var sequence = MessageSequence.fromAll();
      expect(sequence.toString(), '1:*');
    });
    test('from id', () {
      var sequence = MessageSequence.fromId(12);
      expect(sequence.toString(), '12');
    });
    test('from last', () {
      var sequence = MessageSequence.fromLast();
      expect(sequence.toString(), '*');
    });
    test('from range', () {
      var sequence = MessageSequence.fromRange(12, 17);
      expect(sequence.toString(), '12:17');
    });
    test('from range to last', () {
      var sequence = MessageSequence.fromRangeToLast(12);
      expect(sequence.toString(), '12:*');
    });
  });

  group('Parse', () {
    test('1 id', () {
      var sequence = MessageSequence.parse('1');
      expect(sequence.toString(), '1');
    });
    test('2 ids', () {
      var sequence = MessageSequence.parse('18,7');
      expect(sequence.toString(), '18,7');
    });
    test('2 ids, 1 range', () {
      var sequence = MessageSequence.parse('18,7,233:244');
      expect(sequence.toString(), '18,7,233:244');
    });
    test('last', () {
      var sequence = MessageSequence.parse('*');
      expect(sequence.toString(), '*');
    });
    test('id + last', () {
      var sequence = MessageSequence.parse('*,234');
      expect(sequence.toString(), '*,234');
    });
    test('range to last', () {
      var sequence = MessageSequence.parse('17:*');
      expect(sequence.toString(), '17:*');
    });
    test('id and range to last', () {
      var sequence = MessageSequence.parse('17:*,5');
      expect(sequence.toString(), '17:*,5');
    });
  });

  group('Parse sorted', () {
    test('2 ids', () {
      var sequence = MessageSequence.parse('18,7');
      expect((sequence..sorted()).toString(), '7,18');
    });
    test('2 ids, 1 range', () {
      var sequence = MessageSequence.parse('18,7,233:244');
      expect((sequence..sorted()).toString(), '7,18,233:244');
    });
    test('id + last', () {
      var sequence = MessageSequence.parse('*,234');
      expect((sequence..sorted()).toString(), '234,*');
    });
    test('id and range to last', () {
      var sequence = MessageSequence.parse('17:*,5');
      expect((sequence..sorted()).toString(), '5,17:*');
    });
  });

  group('List', () {
    test('1 id', () {
      var sequence = MessageSequence.fromId(1);
      expect(sequence.toList(), [1]);
    });

    test('3 ids', () {
      var sequence = MessageSequence.fromId(1);
      sequence.add(8);
      sequence.add(7);
      expect(sequence.toList(), [1, 8, 7]);
    });

    test('all', () {
      var sequence = MessageSequence.fromAll();
      try {
        sequence.toList();
        fail(
            'sequence.toList() should fail when * is included an not exists parameter is specified');
      } catch (e) {
        // expected
      }
      expect(sequence.toList(7), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('range', () {
      var sequence = MessageSequence.fromRange(17, 21);
      expect(sequence.toList(), [17, 18, 19, 20, 21]);
    });

    test('range with single id', () {
      var sequence = MessageSequence.fromRange(17, 21);
      sequence.add(12);
      expect(sequence.toList(), [17, 18, 19, 20, 21, 12]);
    });

    test('rangeToLast', () {
      var sequence = MessageSequence.fromRangeToLast(17);
      expect(sequence.toList(20), [17, 18, 19, 20]);
    });

    test('id, range, rangeToLast', () {
      var sequence = MessageSequence.fromRangeToLast(17);
      sequence.addRange(5, 8);
      sequence.add(3);
      expect(sequence.toList(20), [17, 18, 19, 20, 5, 6, 7, 8, 3]);
    });
  });

  group('List sorted', () {
    test('3 ids', () {
      var sequence = MessageSequence.fromId(1);
      sequence.add(8);
      sequence.add(7);
      expect((sequence..sorted()).toList(), [1, 7, 8]);
    });

    test('range with single id', () {
      var sequence = MessageSequence.fromRange(17, 21);
      sequence.add(12);
      expect((sequence..sorted()).toList(), [12, 17, 18, 19, 20, 21]);
    });

    test('id, range, rangeToLast', () {
      var sequence = MessageSequence.fromRangeToLast(17);
      sequence.addRange(5, 8);
      sequence.add(3);
      expect((sequence..sorted()).toList(20), [3, 5, 6, 7, 8, 17, 18, 19, 20]);
    });
  });
}
