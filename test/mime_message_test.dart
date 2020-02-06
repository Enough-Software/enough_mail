import 'package:test/test.dart';
import 'package:enough_mail/mime_message.dart';

void main() {
  group('content type tests', () {
    test('content-type parsing 1', () {
      var contentTypeValue = 'text/html; charset=ISO-8859-1';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/html');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'html');
      expect(type.charset, 'iso-8859-1');
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-1');
    });

    
    test('content-type parsing 2', () {
      var contentTypeValue = 'text/plain; charset="UTF-8"';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/plain');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'plain');
      expect(type.charset, 'utf-8');
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], '"UTF-8"');
    });

    test('content-type parsing 3', () {
      var contentTypeValue = 'multipart/alternative; boundary=bcaec520ea5d6918e204a8cea3b4';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'multipart/alternative');
      expect(type.typeBase, 'multipart');
      expect(type.typeExtension, 'alternative');
      expect(type.charset, isNull);
      expect(type.boundary, 'bcaec520ea5d6918e204a8cea3b4');
      expect(type.elements, isNotNull);
      expect(type.elements['boundary'], 'bcaec520ea5d6918e204a8cea3b4');
    });

    test('content-type parsing 4', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format=flowed';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/plain');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'plain');
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-15');
      expect(type.elements['format'], 'flowed');
    });

    
    test('content-type parsing 5', () {
      var contentTypeValue = 'text/plain; charset=ISO-8859-15; format="Flowed"';
      var type = ContentTypeHeader.fromValue(contentTypeValue);
      expect(type, isNotNull);
      expect(type.typeText, 'text/plain');
      expect(type.typeBase, 'text');
      expect(type.typeExtension, 'plain');
      expect(type.charset, 'iso-8859-15');
      expect(type.isFlowedFormat, isTrue);
      expect(type.boundary, isNull);
      expect(type.elements, isNotNull);
      expect(type.elements['charset'], 'ISO-8859-15');
      expect(type.elements['format'], '"Flowed"');
    });
  });
}
