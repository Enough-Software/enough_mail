import 'package:enough_mail/src/imap/message_sequence.dart';
import 'package:test/test.dart';

void main() {
  group('MessageSequence Tests', () {
    group('Add ids', () {
      test('1 id', () {
        final sequence = MessageSequence();
        [1].forEach(sequence.add);
        expect(sequence.toString(), '1');
      });

      test('1 uid', () {
        final sequence = MessageSequence(isUidSequence: true);
        [12345].forEach(sequence.add);
        final buffer = StringBuffer();
        sequence.render(buffer);
        expect(buffer.toString(), '12345');
        expect(sequence.toString(), '12345');
      });
      test('3 separate ids', () {
        final sequence = MessageSequence();
        [1, 999, 7].forEach(sequence.add);
        expect(sequence.toString(), '1,999,7');
      });
      test('4 ids with range', () {
        final sequence = MessageSequence();
        [1, 7, 5, 6].forEach(sequence.add);
        expect(sequence.toString(), '1,7,5:6');
      });

      test('9 ids with range', () {
        final sequence = MessageSequence();
        [1, 7, 5, 6, 9, 12, 11, 10, 2].forEach(sequence.add);
        expect(sequence.toString(), '1,7,5:6,9,12,11,10,2');
      });
      test('9 ids with range but last', () {
        final sequence = MessageSequence();
        [1, 7, 5, 6, 9, 13, 11, 10, 2].forEach(sequence.add);
        expect(sequence.toString(), '1,7,5:6,9,13,11,10,2');
      });
    });

    group('Add ids sorted', () {
      test('1 id', () {
        final sequence = MessageSequence();
        [1].forEach(sequence.add);
        expect(sequence.toString(), '1');
      });
      test('3 separate ids', () {
        final sequence = MessageSequence();
        [1, 999, 7].forEach(sequence.add);
        expect((sequence..sort()).toString(), '1,7,999');
      });
      test('4 ids with range', () {
        final sequence = MessageSequence();
        [1, 7, 5, 6].forEach(sequence.add);
        expect((sequence..sort()).toString(), '1,5:7');
      });

      test('9 ids with range', () {
        final sequence = MessageSequence();
        [1, 7, 5, 6, 9, 12, 11, 10, 2].forEach(sequence.add);
        expect((sequence..sort()).toString(), '1:2,5:7,9:12');
      });
      test('9 ids with range but last', () {
        final sequence = MessageSequence();
        [1, 7, 5, 6, 9, 13, 11, 10, 2].forEach(sequence.add);
        expect((sequence..sort()).toString(), '1:2,5:7,9:11,13');
      });
    });

    group('Add Last', () {
      test('Only last', () {
        final sequence = MessageSequence()..addLast();
        expect(sequence.toString(), '*');
      });
      test('id + last', () {
        final sequence = MessageSequence();
        [232].forEach(sequence.add);
        sequence.addLast();
        expect(sequence.toString(), '232,*');
      });
    });

    group('Add ranges', () {
      test('1 range', () {
        final sequence = MessageSequence()..addRange(12, 277);
        expect(sequence.toString(), '12:277');
      });
      test('2 ranges', () {
        final sequence = MessageSequence()
          ..addRange(12, 277)
          ..addRange(1, 7);
        expect(sequence.toString(), '12:277,1:7');
      });
      test('2 ranges with id and last', () {
        final sequence = MessageSequence();
        [2312].forEach(sequence.add);
        sequence
          ..addRange(12, 277)
          ..addRange(1, 7)
          ..addLast();
        expect(sequence.toString(), '2312,12:277,1:7,*');
      });
    });

    group('Add range-to-last', () {
      test('1 range to last', () {
        final sequence = MessageSequence()..addRangeToLast(12);
        expect(sequence.toString(), '12:*');
      });
      test('1 range to end, 1 normal range', () {
        final sequence = MessageSequence()
          ..addRangeToLast(12)
          ..addRange(1, 7);
        expect(sequence.toString(), '12:*,1:7');
      });
      test('mixed ranges', () {
        final sequence = MessageSequence();
        [2312, 2322].forEach(sequence.add);
        sequence
          ..addRange(12, 277)
          ..addRangeToLast(23290);
        expect(sequence.toString(), '2312,2322,12:277,23290:*');
      });
    });

    group('Add all', () {
      test('Just all', () {
        final sequence = MessageSequence()..addAll();
        expect(sequence.toString(), '1:*');
      });
      test('all + 1 id', () {
        final sequence = MessageSequence()
          ..add(12)
          ..addAll();
        expect(sequence.toString(), '12,1:*');
      });
    });

    group('Convenience methods', () {
      test('from all', () {
        final sequence = MessageSequence.fromAll();
        expect(sequence.toString(), '1:*');
      });
      test('from id', () {
        final sequence = MessageSequence.fromId(12);
        expect(sequence.toString(), '12');
      });
      test('from last', () {
        final sequence = MessageSequence.fromLast();
        expect(sequence.toString(), '*');
      });
      test('from range', () {
        final sequence = MessageSequence.fromRange(12, 17);
        expect(sequence.toString(), '12:17');
      });
      test('from range to last', () {
        final sequence = MessageSequence.fromRangeToLast(12);
        expect(sequence.toString(), '12:*');
      });
    });

    group('Parse', () {
      test('1 id', () {
        final sequence = MessageSequence.parse('1');
        expect(sequence.toString(), '1');
      });
      test('2 ids', () {
        final sequence = MessageSequence.parse('18,7');
        expect(sequence.toString(), '18,7');
      });
      test('2 ids, 1 range', () {
        final sequence = MessageSequence.parse('18,7,233:244');
        expect(sequence.toString(), '18,7,233:244');
      });
      test('last', () {
        final sequence = MessageSequence.parse('*');
        expect(sequence.toString(), '*');
      });
      test('id + last', () {
        final sequence = MessageSequence.parse('*,234');
        expect(sequence.toString(), '*,234');
      });
      test('range to last', () {
        final sequence = MessageSequence.parse('17:*');
        expect(sequence.toString(), '17:*');
      });
      test('id and range to last', () {
        final sequence = MessageSequence.parse('17:*,5');
        expect(sequence.toString(), '17:*,5');
      });
      test('NIL', () {
        final sequence = MessageSequence.parse('NIL');
        expect(sequence.toString(), 'NIL');
      });
    });

    group('Parse sorted', () {
      test('2 ids', () {
        final sequence = MessageSequence.parse('18,7');
        expect((sequence..sort()).toString(), '7,18');
      });
      test('2 ids, 1 range', () {
        final sequence = MessageSequence.parse('18,7,233:244');
        expect((sequence..sort()).toString(), '7,18,233:244');
      });
      test('id + last', () {
        final sequence = MessageSequence.parse('*,234');
        expect((sequence..sort()).toString(), '234,*');
      });
      test('id and range to last', () {
        final sequence = MessageSequence.parse('17:*,5');
        expect((sequence..sort()).toString(), '5,17:*');
      });
    });

    group('List', () {
      test('1 id', () {
        final sequence = MessageSequence.fromId(1);
        expect(sequence.toList(), [1]);
      });

      test('3 ids', () {
        final sequence = MessageSequence.fromId(1)
          ..add(8)
          ..add(7);
        expect(sequence.toList(), [1, 8, 7]);
      });

      test('all', () {
        final sequence = MessageSequence.fromAll();
        try {
          sequence.toList();
          fail('sequence.toList() should fail when * is included an not '
              'exists parameter is specified');
        } catch (e) {
          // expected
        }
        expect(sequence.toList(7), [1, 2, 3, 4, 5, 6, 7]);
      });

      test('range', () {
        final sequence = MessageSequence.fromRange(17, 21);
        expect(sequence.toList(), [17, 18, 19, 20, 21]);
      });

      test('range with single id', () {
        final sequence = MessageSequence.fromRange(17, 21)..add(12);
        expect(sequence.toList(), [17, 18, 19, 20, 21, 12]);
      });

      test('rangeToLast', () {
        final sequence = MessageSequence.fromRangeToLast(17);
        expect(sequence.toList(20), [17, 18, 19, 20]);
      });

      test('id, range, rangeToLast', () {
        final sequence = MessageSequence.fromRangeToLast(17)
          ..addRange(5, 8)
          ..add(3);
        expect(sequence.toList(20), [17, 18, 19, 20, 5, 6, 7, 8, 3]);
      });
      test('NIL', () {
        final sequence = MessageSequence.parse('NIL');
        expect(sequence.toList, throwsStateError);
      });
    });

    group('List sorted', () {
      test('3 ids', () {
        final sequence = MessageSequence.fromId(1)
          ..add(8)
          ..add(7);
        expect((sequence..sort()).toList(), [1, 7, 8]);
      });

      test('range with single id', () {
        final sequence = MessageSequence.fromRange(17, 21)..add(12);
        expect((sequence..sort()).toList(), [12, 17, 18, 19, 20, 21]);
      });

      test('id, range, rangeToLast', () {
        final sequence = MessageSequence.fromRangeToLast(17)
          ..addRange(5, 8)
          ..add(3);
        expect((sequence..sort()).toList(20), [3, 5, 6, 7, 8, 17, 18, 19, 20]);
      });
    });
  });
  group('PagedMessageSequence Tests', () {
    test('4 pages', () {
      final sequence = MessageSequence.fromIds(
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16]);
      final paged = PagedMessageSequence(sequence, pageSize: 4);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [13, 14, 15, 16]);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [9, 10, 11, 12]);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [5, 6, 7, 8]);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [1, 2, 3, 4]);
      expect(paged.hasNext, isFalse);
    });
    test('not full page', () {
      final sequence = MessageSequence.fromIds([1, 2]);
      final paged = PagedMessageSequence(sequence, pageSize: 4);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [1, 2]);
      expect(paged.hasNext, isFalse);
    });
    test('one more than a single page', () {
      final sequence = MessageSequence.fromIds([1, 2, 3, 4, 5]);
      final paged = PagedMessageSequence(sequence, pageSize: 4);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [2, 3, 4, 5]);
      expect(paged.hasNext, isTrue);
      expect(paged.next().toList(), [1]);
      expect(paged.hasNext, isFalse);
    });
  });

  group('SequenceNode Tests', () {
    test('latestId', () {
      final t1 = SequenceNode.root(isUid: true)
        ..addChild(17)
        ..addChild(18)
        ..addChild(20);
      final t2 = SequenceNode.root(isUid: true)
        ..addChild(19)
        ..addChild(21);

      final threadData = SequenceNode.root(isUid: true)
        ..children.addAll([t1, t2]);
      expect(threadData[0].latestId, 20);
      expect(threadData[1].latestId, 21);
    });
  });
}
