import 'dart:convert' as convert;

abstract class JsonSerializable {
  bool _isValueWritten = false;
  void writeJson(StringBuffer buffer);
  void readJson(Map<String, dynamic> json);

  String toJson([StringBuffer buffer]) {
    buffer ??= StringBuffer();
    _isValueWritten = false;
    writeObject(null, this, buffer);
    return buffer.toString();
  }

  void fromJson(String source) {
    var json = convert.jsonDecode(source);
    readJson(json);
  }

  void writeText(String name, String value, StringBuffer buffer) {
    if (_isValueWritten) {
      buffer.write(',');
    }
    buffer..write('"')..write(name)..write('": ');
    writeTextValue(value, buffer);
    _isValueWritten = true;
  }

  void writeInt(String name, int value, StringBuffer buffer) {
    if (_isValueWritten) {
      buffer.write(',');
    }
    buffer..write('"')..write(name)..write('": ')..write(value);
    _isValueWritten = true;
  }

  void writeBool(String name, bool value, StringBuffer buffer) {
    if (_isValueWritten) {
      buffer.write(',');
    }
    buffer..write('"')..write(name)..write('": ')..write(value);
    _isValueWritten = true;
  }

  void writeObject(String name, JsonSerializable value, StringBuffer buffer) {
    if (_isValueWritten) {
      buffer.write(',');
    }
    if (name != null) {
      buffer..write('"')..write(name)..write('": ');
    }
    if (value == null) {
      buffer.write('null');
    } else {
      value._isValueWritten = false;
      buffer.write('{');
      value.writeJson(buffer);
      buffer.write('}');
    }
    _isValueWritten = true;
  }

  void writeList(
      String name, List<JsonSerializable> values, StringBuffer buffer) {
    if (_isValueWritten) {
      buffer.write(',');
    }
    if (name != null) {
      buffer..write('"')..write(name)..write('": ');
    }
    writeListValues(values, buffer);
    _isValueWritten = true;
  }

  static void writeListValues(
      List<JsonSerializable> values, StringBuffer buffer) {
    if (values == null) {
      buffer.write('null');
      return;
    }
    buffer.write('[');
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      value._isValueWritten = false;
      value.writeObject(null, value, buffer);
      if (i < values.length - 1) {
        buffer.write(',');
      }
    }
    buffer.write(']');
  }

  void writeTextValue(String text, StringBuffer buffer) {
    if (text == null) {
      buffer.write('null');
    } else {
      text = text.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      buffer..write('"')..write(text)..write('"');
    }
  }

  String readText(String name, Map<String, dynamic> json) {
    return json[name] as String;
  }

  int readInt(String name, Map<String, dynamic> json) {
    return json[name] as int;
  }

  bool readBool(String name, Map<String, dynamic> json) {
    return json[name] as bool;
  }

  JsonSerializable readObject(
      String name, Map<String, dynamic> json, JsonSerializable result) {
    var subtree = json[name] as Map<String, dynamic>;
    if (subtree == null) {
      return null;
    }
    result.readJson(subtree);
    return result;
  }

  List<JsonSerializable> readList(String name, Map<String, dynamic> json,
      JsonSerializable Function() creator, List<JsonSerializable> result) {
    var iteratableJson = json[name] as Iterable;
    if (iteratableJson == null) {
      return null;
    }
    readListValues(iteratableJson, creator, result);
    return result;
  }

  static void readListValues(Iterable json, JsonSerializable Function() creator,
      List<JsonSerializable> result) {
    for (final json in json) {
      final jsonSerializable = creator();
      jsonSerializable.readJson(json);
      result.add(jsonSerializable);
    }
  }

  static String listToJson(List<JsonSerializable> values,
      [StringBuffer buffer]) {
    buffer ??= StringBuffer();
    writeListValues(values, buffer);
    return buffer.toString();
  }

  static void listFromJson(String source, JsonSerializable Function() creator,
      List<JsonSerializable> resultList) {
    final iteratableJson = convert.jsonDecode(source);
    readListValues(iteratableJson, creator, resultList);
  }
}
