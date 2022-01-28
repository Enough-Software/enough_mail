import '../../codecs.dart';
import '../private/imap/parser_helper.dart';

/// Contains classes to support [RFC 2971](https://datatracker.ietf.org/doc/html/rfc2971)

class Id {
  /// Creates a new ID
  const Id({
    this.name,
    this.version,
    this.os,
    this.osVersion,
    this.vendor,
    this.supportUrl,
    this.address,
    this.date,
    this.command,
    this.arguments,
    this.environment,
    this.nonStandardFields = const <String, String>{},
  });

  /// Name of the program
  final String? name;

  /// Version number of the program
  final String? version;

  /// Name of the operating system
  final String? os;

  /// Version of the operating system
  final String? osVersion;

  /// Vendor of the client/server
  final String? vendor;

  /// URL to contact for support
  final String? supportUrl;

  /// Postal address of contact/vendor
  final String? address;

  /// Date program was released, specified as a date-time in IMAP4rev1
  final DateTime? date;

  /// Command used to start the program
  final String? command;

  /// Arguments supplied on the command line, if any
  final String? arguments;

  /// Description of environment,
  /// i.e., UNIX environment variables or Windows registry settings
  final String? environment;

  /// Any other, non-standard properties
  final Map<String, String> nonStandardFields;

  /// Checks if this ID is empty ie it contains no values
  bool get isEmpty =>
      name == null &&
      version == null &&
      os == null &&
      osVersion == null &&
      vendor == null &&
      supportUrl == null &&
      address == null &&
      date == null &&
      command == null &&
      arguments == null &&
      environment == null &&
      nonStandardFields.isEmpty;

  static const _standardFieldNames = [
    'name',
    'version',
    'os',
    'os-version',
    'vendor',
    'support-url',
    'address',
    'date',
    'command',
    'arguments',
    'environment'
  ];

  /// Creates an ID from the given [text]
  static Id? fromText(String text) {
    if (text == 'NIL' || !text.startsWith('(')) {
      return null;
    }
    final entries = ParserHelper.parseListEntries(text, 1, ')', ' ')!;
    final map = <String, String>{};
    for (var i = 0; i < entries.length - 1; i += 2) {
      final name = _stripQuotes(entries[i]).toLowerCase();
      final value = _stripQuotes(entries[i + 1]);
      map[name] = value;
    }
    return Id(
      name: map.remove('name'),
      version: map.remove('version'),
      os: map.remove('os'),
      osVersion: map.remove('os-version'),
      vendor: map.remove('vendor'),
      supportUrl: map.remove('support-url'),
      address: map.remove('address'),
      date: _parseDate(map.remove('date')),
      command: map.remove('command'),
      arguments: map.remove('arguments'),
      environment: map.remove('environment'),
      nonStandardFields: map,
    );
  }

  static String _stripQuotes(String input) {
    if (input.startsWith('"')) {
      return input.substring(1, input.length - 1);
    }
    return input;
  }

  static DateTime? _parseDate(String? input) => DateCodec.decodeDate(input);

  @override
  String toString() {
    if (isEmpty) {
      return 'NIL';
    }
    final standardValues = [
      name,
      version,
      os,
      osVersion,
      vendor,
      supportUrl,
      address,
      date,
      command,
      arguments,
      environment,
    ];
    final buffer = StringBuffer()..write('(');
    var addSpace = false;
    for (var i = 0; i < standardValues.length; i++) {
      final value = standardValues[i];
      if (value != null) {
        if (addSpace) {
          buffer.write(' ');
        } else {
          addSpace = true;
        }
        final name = _standardFieldNames[i];
        buffer
          ..write('"')
          ..write(name)
          ..write('" ')
          ..write('"')
          ..write(value)
          ..write('"');
      }
    }
    buffer.write(')');
    return buffer.toString();
  }
}
