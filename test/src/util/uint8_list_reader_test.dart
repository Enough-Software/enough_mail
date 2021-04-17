import 'package:test/test.dart';
import 'dart:typed_data';
import 'package:enough_mail/src/util/uint8_list_reader.dart';

String _toString(Uint8List bytes) {
  return String.fromCharCodes(bytes);
}

void main() {
  test('Uint8ListReader.readLine() with simple input', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in one', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\nHI\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 2 lines', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    reader.addText('HI\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 2+ lines', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    reader.addText('HI\r\nOHMY');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 3 lines', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    reader.addText('HI\r\n');
    reader.addText('YEAH\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
    expect(reader.readLine(), 'YEAH');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines in 3+ lines', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    reader.addText('HI\r\nYEAH');
    reader.addText('\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'HI');
    expect(reader.readLine(), 'YEAH');
  }); // test end

  test('Uint8ListReader.readBytes() with 1 line [1]', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(_toString(reader.readBytes(5)!), 'HELLO');
  }); // test end

  test('Uint8ListReader.readBytes() with 1 line [2]', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(_toString(reader.readBytes(10)!), 'HELLO ()\r\n');
  }); // test end

  test('Uint8ListReader.readBytes()  [3]', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    reader.addText('HI\r\nYEAH');
    reader.addText('\r\n');
    expect(_toString(reader.readBytes(12)!), 'HELLO ()\r\nHI');
  }); // test end

  test('Uint8ListReader.readBytes()  [4]', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    reader.addText('HI\r\nYEAH');
    reader.addText('\r\n');
    expect(_toString(reader.readBytes(12)!), 'HELLO ()\r\nHI');
    expect(_toString(reader.readBytes(5)!), '\r\nYEA');
  }); // test end

  test('Uint8ListReader.readBytes() with text in parts read [5]', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\nHI\r\nYEAH\r\n');
    expect(_toString(reader.readBytes(2)!), 'HE');
    expect(_toString(reader.readBytes(5)!), 'LLO (');
    expect(_toString(reader.readBytes(5)!), ')\r\nHI');
    expect(_toString(reader.readBytes(7)!), '\r\nYEAH\r');
    expect(_toString(reader.readBytes(1)!), '\n');
  }); // test end

  test('Uint8ListReader.readLine() and readBytes()', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\nHI\r\nYEAH\r\n');
    expect(reader.readLine(), 'HELLO ()');
    expect(_toString(reader.readBytes(4)!), 'HI\r\n');
    expect(reader.readLine(), 'YEAH');
  }); // test end

  test('Uint8ListReader.readLine() without newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\r\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.readLine() with break in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.readLine() with 2 lines with no break in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\nWORLD ()\r\n');
    expect(reader.findLineBreak(), 9);
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'WORLD ()');
  });

  test('Uint8ListReader.findLineBreak() with 2 lines and break in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\nWORLD ()\r\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.findLineBreak(), 9);
  });

  test('Uint8ListReader.readLine() with 2 lines and break in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\nWORLD ()\r\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.readLine(), 'HELLO ()');
    expect(reader.readLine(), 'WORLD ()');
  });

  test('Uint8ListReader.readLines() with 2 lines and break in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\nWORLD ()\r\n');
    expect(reader.readLines(), ['HELLO ()', 'WORLD ()']);
    reader.addText('HELLO ()\r');
    reader.addText('\nWORLD ()\r\n');
    expect(reader.readLines(), ['HELLO ()', 'WORLD ()']);
  });

  test('Uint8ListReader.readLine() with 2 breaks in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()');
    expect(reader.hasLineBreak(), false);
    expect(reader.readLine(), null);
    reader.addText('\r');
    reader.addText('\n');
    expect(reader.hasLineBreak(), true);
    expect(reader.findLineBreak(), reader.findLastLineBreak());
    expect(reader.readLine(), 'HELLO ()');
  }); // test end

  test('Uint8ListReader.findLineBreak() simple case', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r\n');
    var pos = reader.findLineBreak();
    expect(pos, 9);
  }); // test end

  test('Uint8ListReader.findLineBreak() with break in newline', () {
    var reader = Uint8ListReader();
    reader.addText('HELLO ()\r');
    expect(reader.findLineBreak(), null);
    reader.addText('\n');
    var pos = reader.findLineBreak();
    expect(pos, 9);
  }); // test end
}
