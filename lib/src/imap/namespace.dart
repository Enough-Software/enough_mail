import '../codecs/modified_utf7_codec.dart';

/// One namespace as advertised in an IMAP `NAMESPACE` response,
/// compare [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342).
class Namespace {
  /// Creates a new namespace from its wire form.
  ///
  /// [encodedPrefix] is the prefix as sent by the server, i.e. in
  /// modified UTF-7 unless the server supports `UTF8=ACCEPT`; [prefix]
  /// is the decoded form.
  Namespace({
    required this.encodedPrefix,
    this.delimiter,
    this.extensions = const {},
  }) : prefix = _modifiedUtf7Codec.decodeText(encodedPrefix);

  static const ModifiedUtf7Codec _modifiedUtf7Codec = ModifiedUtf7Codec();

  /// The prefix as the server sent it, e.g. `Echoes/` or `#shared&-1/`
  final String encodedPrefix;

  /// The decoded prefix, e.g. `Echoes/` or `#shared&1/`
  final String prefix;

  /// The hierarchy delimiter used within this namespace, `null` when
  /// the server answered `NIL`, i.e. the namespace has no hierarchy.
  final String? delimiter;

  /// Optional response extensions by name, e.g. `X-PARAM: [FLAG1, FLAG2]`.
  final Map<String, List<String>> extensions;

  @override
  String toString() {
    final buffer = StringBuffer('("$encodedPrefix" ')
      ..write(delimiter == null ? 'NIL' : '"$delimiter"');
    for (final extension in extensions.entries) {
      buffer
        ..write(' "${extension.key}" (')
        ..write(extension.value.map((value) => '"$value"').join(' '))
        ..write(')');
    }
    buffer.write(')');

    return buffer.toString();
  }
}

/// The result of an IMAP `NAMESPACE` command,
/// compare [RFC 2342](https://datatracker.ietf.org/doc/html/rfc2342).
///
/// Each list is empty when the server answered `NIL` for that class.
class NamespaceResponse {
  /// Creates a new namespace response
  const NamespaceResponse({
    this.personal = const [],
    this.otherUsers = const [],
    this.shared = const [],
  });

  /// The namespaces within the personal scope of the authenticated user;
  /// `INBOX` always lives in one of them.
  final List<Namespace> personal;

  /// The namespaces holding mailboxes of other users that the
  /// authenticated user has been granted access to.
  final List<Namespace> otherUsers;

  /// The namespaces holding mailboxes shared between users.
  final List<Namespace> shared;

  @override
  String toString() =>
      'NAMESPACE ${_format(personal)} ${_format(otherUsers)} '
      '${_format(shared)}';

  static String _format(List<Namespace> namespaces) =>
      namespaces.isEmpty ? 'NIL' : '(${namespaces.join()})';
}
