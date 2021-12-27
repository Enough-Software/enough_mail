import 'dart:typed_data';

import 'package:enough_mail/src/private/util/uint8_list_reader.dart';
import 'package:test/test.dart';

String _toString(Uint8List bytes) => String.fromCharCodes(bytes);

void main() {
  test('Uint8ListReader.readLine() with simple input', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in one', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\nHI\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 2 lines', () {
    final reader = Uint8ListReader()
      ..addText('HELLO ()\r\n')
      ..addText('HI\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 2+ lines', () {
    final reader = Uint8ListReader()
      ..addText('HELLO ()\r\n')
      ..addText('HI\r\nOHMY');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 3 lines', () {
    final reader = Uint8ListReader()
      ..addText('HELLO ()\r\n')
      ..addText('HI\r\n')
      ..addText('YEAH\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
    expect(reader.readLine(), 'YEAH');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 3+ lines', () {
    final reader = Uint8ListReader()
      ..addText('HELLO ()\r\n')
      ..addText('HI\r\nYEAH')
      ..addText('\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
    expect(reader.readLine(), 'YEAH');
  }); // test end

  test('Uint8ListReader.readBytes() with 1 line [1]', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(_toString(reader.readBytes(5)!), 'HELLO');
  }); // test end

  test('Uint8ListReader.readBytes() with 1 line [2]', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(_toString(reader.readBytes(10)!), 'HELLO ()\r\n');
  }); // test end

  test('Uint8ListReader.readBytes()  [3]', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    reader
      ..addText('HI\r\nYEAH')
      ..addText('\r\n');
    expect(_toString(reader.readBytes(12)!), 'HELLO ()\r\nHI');
  }); // test end

  test('Uint8ListReader.readBytes()  [4]', () {
    final reader = Uint8ListReader()
      ..addText('HELLO ()\r\n')
      ..addText('HI\r\nYEAH')
      ..addText('\r\n');
    expect(_toString(reader.readBytes(12)!), 'HELLO ()\r\nHI');
    expect(_toString(reader.readBytes(5)!), '\r\nYEA');
  }); // test end

  test('Uint8ListReader.readBytes() with text in parts read [5]', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\nHI\r\nYEAH\r\n');
    expect(_toString(reader.readBytes(2)!), 'HE');
    expect(_toString(reader.readBytes(5)!), 'LLO (');
    expect(_toString(reader.readBytes(5)!), ')\r\nHI');
    expect(_toString(reader.readBytes(7)!), '\r\nYEAH\r');
    expect(_toString(reader.readBytes(1)!), '\n');
  }); // test end

  test('Uint8ListReader.readLine() and readBytes()', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\nHI\r\nYEAH\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(_toString(reader.readBytes(4)!), 'HI\r\n');
    expect(reader.readLine(), 'YEAH');
  }); // test end

  test('Uint8ListReader.readLine() without newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\r\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.readLine() with break in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines with no break in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\nWORLD ()\r\n');
    expect(reader.findLineBreak(), 9);
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'WORLD ()');
  });

  test('Uint8ListReader.findLineBreak() with 2 lines and break in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\nWORLD ()\r\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.findLineBreak(), 9);
  });

  test('Uint8ListReader.readLine() with 2 lines and break in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\nWORLD ()\r\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'WORLD ()');
  });

  test('Uint8ListReader.readLines() with 2 lines and break in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\nWORLD ()\r\n');
    expect(reader.readLines(), ['HELLO ()', 'WORLD ()']);
    reader
      ..addText('HELLO ()\r')
      ..addText('\nWORLD ()\r\n');
    expect(reader.readLines(), ['HELLO ()', 'WORLD ()']);
  });

  test('Uint8ListReader.readLine() with 2 breaks in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader
      ..addText('\r')
      ..addText('\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.findLineBreak() simple case', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r\n');
    final pos = reader.findLineBreak();
    expect(pos, 9);
  }); // test end

  test('Uint8ListReader.findLineBreak() with break in newline', () {
    final reader = Uint8ListReader()..addText('HELLO ()\r');
    expect(reader.findLineBreak(), null);
    reader.addText('\n');
    final pos = reader.findLineBreak();
    expect(pos, 9);
  }); // test end
}
